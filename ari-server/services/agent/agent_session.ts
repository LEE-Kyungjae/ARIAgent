import { Agent } from "@mariozechner/pi-agent-core";
import { AgentInfo } from "../../models/agent.js";
import { AIProviders } from "../../models/settings.js";
import { PendingAgentResponse } from "../../models/agent_response.js";
import { appendChatLog } from "../../repositories/chat_log_repository.js";
import { appendUsageLog } from "../../repositories/usage_repository.js";
import { UserSocketHandler } from "../../system/ws.js";
import {
  extractFinalResponseText,
  extractTextFromAgentMessage,
} from "./response_parser.js";
import {
  getAttemptOrder,
  isOAuthProvider,
  resolveApiKey,
  resolveModel,
} from "./provider_selector.js";
import {
  cloneActiveSkills,
  loadSkillsForPrompt,
  mergeActiveSkill,
} from "../tools/skill_registry.js";
import {
  buildSessionTools,
  buildSessionToolsSync,
} from "../tools/tool_registry.js";
import { logger } from "../../infra/logger.js";
import { t } from "../../infra/i18n.js";
import { getSettings } from "../../repositories/setting_repository.js";
import { Settings } from "../../models/settings.js";
import { markAgentIdle, markAgentWorking } from "./runtime_state.js";

function parseProviderErrorMessage(raw: string): string {
  if (!raw) return "";
  try {
    const parsed = JSON.parse(raw);
    if (parsed?.detail) return String(parsed.detail);
    if (parsed?.message) return String(parsed.message);
    if (parsed?.error) return String(parsed.error);
  } catch {}
  return raw;
}

export class AgentSession {
  agent!: Agent;
  agentInfo: AgentInfo;
  resolvedApiKey: string;
  pendingResponses: PendingAgentResponse[] = [];
  private requestWaiters = new Map<
    string,
    {
      resolve: (responseText: string) => void;
      reject: (error: Error) => void;
    }
  >();
  currentPendingResponse: PendingAgentResponse | null = null;
  currentResponseText = "";
  currentRequestAnnounced = false;
  hasResponseBridge = false;
  currentProvider = "";
  currentModel = "";
  private _pendingMeta: { provider: string; model: string; usage: any } | null = null;
  private _isInRetryLoop = false;

  constructor(agentInfo: AgentInfo) {
    this.agentInfo = agentInfo;
    this.resolvedApiKey = "";
  }

  resetTurnScopedSkills(): void {
    this.agentInfo.resetTurnScopedSkills();
  }

  private shouldBroadcastPending(pending: PendingAgentResponse): boolean {
    if (pending.source !== "task") {
      return true;
    }
    return getSettings(new Settings()).SHOW_TASK_MESSAGES === true;
  }

  private async refreshRuntimeTools(): Promise<void> {
    const nextTools = await buildSessionTools(
      this.agentInfo.activeSkillToolNames,
    );
    this.agentInfo.runtimeTools.splice(
      0,
      this.agentInfo.runtimeTools.length,
      ...nextTools,
    );
    this.agent.setTools(this.agentInfo.runtimeTools);
  }

  private refreshRuntimeToolsSync(): void {
    const nextTools = buildSessionToolsSync(
      this.agentInfo.activeSkillToolNames,
    );
    this.agentInfo.runtimeTools.splice(
      0,
      this.agentInfo.runtimeTools.length,
      ...nextTools,
    );
    this.agent.setTools(this.agentInfo.runtimeTools);
  }

  private async preloadCurrentAppSkill(): Promise<void> {
    const appId = this.agentInfo.appId?.trim();
    if (!appId) {
      return;
    }

    const alreadyLoaded = this.agentInfo.activeSkills.some(
      (skill) => skill.name === appId,
    );
    if (alreadyLoaded) {
      return;
    }

    const skills = await loadSkillsForPrompt();
    const currentApp = skills.find(
      (skill) => skill.name === appId && skill.isApp,
    );
    if (!currentApp) {
      return;
    }

    this.agentInfo.activeSkills = mergeActiveSkill(
      this.agentInfo.activeSkills,
      {
        ok: true,
        name: currentApp.name,
        description: currentApp.description,
        tools: currentApp.tools,
        content: currentApp.content,
        isApp: true,
      },
    );
    logger.info(`[Agent] Preloaded current app skill: ${appId}`);
  }

  enqueueRequest(pending: PendingAgentResponse): void {
    this.pendingResponses.push(pending);
  }

  waitForRequestCompletion(requestId: string): Promise<string> {
    return new Promise<string>((resolve, reject) => {
      this.requestWaiters.set(requestId, { resolve, reject });
    });
  }

  private resolveRequestWaiter(requestId: string, responseText: string): void {
    const waiter = this.requestWaiters.get(requestId);
    if (!waiter) {
      return;
    }
    this.requestWaiters.delete(requestId);
    waiter.resolve(responseText);
  }

  private rejectRequestWaiter(requestId: string, error: Error): void {
    const waiter = this.requestWaiters.get(requestId);
    if (!waiter) {
      return;
    }
    this.requestWaiters.delete(requestId);
    waiter.reject(error);
  }

  beginNextRequest(): void {
    const nextPending = this.pendingResponses[0] ?? null;
    if (this.currentPendingResponse?.requestId !== nextPending?.requestId) {
      this.currentRequestAnnounced = false;
    }
    this.currentPendingResponse ??= nextPending;
  }

  removeRequest(requestId: string): void {
    const pending =
      this.currentPendingResponse ||
      this.pendingResponses.find((item) => item.requestId === requestId) ||
      null;
    if (this.currentPendingResponse?.requestId === requestId) {
      this.currentPendingResponse = null;
      this.currentRequestAnnounced = false;
    }
    const index = this.pendingResponses.findIndex(
      (pending) => pending.requestId === requestId,
    );
    if (index !== -1) {
      this.pendingResponses.splice(index, 1);
    }
    if (pending) {
      markAgentIdle(pending.agentId);
    }
    this.rejectRequestWaiter(requestId, new Error("Request aborted."));
  }

  resetRequestQueue(): void {
    for (const requestId of this.requestWaiters.keys()) {
      this.rejectRequestWaiter(requestId, new Error("Request queue reset."));
    }
    this.pendingResponses = [];
    this.currentPendingResponse = null;
    this.currentResponseText = "";
    this.currentRequestAnnounced = false;
  }

  completeCurrentRequest(responseText: string, isError = false): void {
    const pending = this.currentPendingResponse ?? this.pendingResponses[0];
    if (!pending) {
      return;
    }

    const index = this.pendingResponses.findIndex(
      (item) => item.requestId === pending.requestId,
    );
    if (index !== -1) {
      this.pendingResponses.splice(index, 1);
    }
    this.currentPendingResponse = null;
    this.currentRequestAnnounced = false;
    this.resolveRequestWaiter(pending.requestId, responseText);
    markAgentIdle(pending.agentId);

    if (this.shouldBroadcastPending(pending)) {
      appendChatLog(pending.agentId, {
        type: "chat",
        isUser: true,
        message: pending.originalMessage,
        requestId: pending.requestId,
        source: pending.source || "user",
      });

      const meta = this._pendingMeta;
      this._pendingMeta = null;

      appendChatLog(pending.agentId, {
        type: "chat",
        isUser: false,
        message: responseText,
        requestId: pending.requestId,
        source: pending.source || "user",
      });

      if (meta && (meta.usage?.totalTokens ?? 0) > 0) {
        appendUsageLog(pending.agentId, {
          requestId: pending.requestId,
          provider: meta.provider,
          model: meta.model,
          usage: meta.usage,
          source: pending.source || "user",
        });
      }

      if (isError) {
        UserSocketHandler.broadcast("/APP.ERROR", {
          ok: false,
          data: {
            message: responseText,
            requestId: pending.requestId,
            agentId: pending.agentId,
            appId: pending.appId,
            source: pending.source || "user",
          },
        });
      } else {
        UserSocketHandler.broadcast("/APP.PUSH", {
          ok: true,
          data: {
            response: responseText,
            requestId: pending.requestId,
            agentId: pending.agentId,
            appId: pending.appId,
            source: pending.source || "user",
          },
        });
      }
    }
  }

  private finalizeCurrentRequest(responseText?: string, isError = false): void {
    if (!this.currentPendingResponse) {
      return;
    }

    const finalText =
      responseText ||
      this.currentResponseText ||
      this.agent.state.error ||
      t("agent.error.processing");

    this.completeCurrentRequest(finalText, isError);
    this.currentResponseText = "";
  }

  ensureLifecycleAttached(): void {
    if (this.hasResponseBridge) {
      return;
    }

    this.agent.setFollowUpMode("one-at-a-time");
    this.agent.subscribe((event) => {
      if (event.type === "turn_start") {
        this._pendingMeta = null;
        this.beginNextRequest();
        const pending = this.currentPendingResponse;
        if (
          pending &&
          !this.currentRequestAnnounced &&
          this.shouldBroadcastPending(pending)
        ) {
          markAgentWorking({
            agentId: pending.agentId,
            requestId: pending.requestId,
            source: pending.source || "user",
          });
          UserSocketHandler.broadcast("/AGENT.REQUEST", {
            message: pending.originalMessage,
            requestId: pending.requestId,
            agentId: pending.agentId,
            appId: pending.appId,
            source: pending.source || "user",
          });
          this.currentRequestAnnounced = true;
        }
        this.currentResponseText = "";
        return;
      }

      if (
        event.type === "message_update" &&
        event.assistantMessageEvent.type === "text_delta"
      ) {
        this.currentResponseText += event.assistantMessageEvent.delta;
        return;
      }

      if (event.type === "turn_end") {
        // 매 턴(툴 호출 포함)마다 usage 누적
        const msg = event.message as any;
        if (msg?.role === "assistant" && msg?.usage) {
          const prev = this._pendingMeta;
          this._pendingMeta = {
            provider: msg.provider ?? prev?.provider ?? "",
            model: msg.model ?? prev?.model ?? "",
            usage: prev?.usage
              ? {
                  input: (prev.usage.input ?? 0) + (msg.usage.input ?? 0),
                  output: (prev.usage.output ?? 0) + (msg.usage.output ?? 0),
                  cacheRead: (prev.usage.cacheRead ?? 0) + (msg.usage.cacheRead ?? 0),
                  cacheWrite: (prev.usage.cacheWrite ?? 0) + (msg.usage.cacheWrite ?? 0),
                  totalTokens: (prev.usage.totalTokens ?? 0) + (msg.usage.totalTokens ?? 0),
                }
              : { ...msg.usage },
          };
        }

        if (this.currentPendingResponse == null) return;

        if (event.toolResults.length > 0) {
          this.currentResponseText = "";
          return;
        }

        const turnText =
          this.currentResponseText || extractTextFromAgentMessage(event.message);
        if (!turnText) {
          // 텍스트 없이 끝난 턴 — 프로바이더 실패 후 재시도 중일 수 있으므로 스킵
          this.currentResponseText = "";
          return;
        }

        this.finalizeCurrentRequest(turnText);
        return;
      }

      if (event.type === "agent_end" && this.currentPendingResponse != null) {
        const errorMessage = this.agent.state.error;
        if (errorMessage && errorMessage.toLowerCase().includes("abort")) {
          markAgentIdle(this.currentPendingResponse.agentId);
          this.removeRequest(this.currentPendingResponse.requestId);
          this.currentResponseText = "";
          return;
        }

        // 재시도 루프 중에는 agent_end 에러를 무시 — runInference가 직접 처리
        if (this._isInRetryLoop && errorMessage) {
          return;
        }

        // error도 없고 response text도 없으면 spurious event (replaceMessages 등에 의한 것) — 스킵
        if (!errorMessage && !this.currentResponseText) {
          return;
        }

        this.finalizeCurrentRequest(errorMessage || undefined);
      }
    });

    this.hasResponseBridge = true;
  }

  async runInference(
    userMessage: string,
    systemPrompt: string,
    providers: AIProviders,
    onProgress?: (message: string) => void,
  ): Promise<{
    responseText: string;
    lastError: Error | null;
    success: boolean;
    aborted?: boolean;
  }> {
    const activeProviders = providers.availableProviders;
    this.resetTurnScopedSkills();
    if (activeProviders.length === 0) {
      return {
        responseText: "",
        lastError: new Error("No active AI providers configured."),
        success: false,
      };
    }

    const agent = this.agent;
    const baseMessages = agent.state.messages.slice();
    const baseSkills = cloneActiveSkills(this.agentInfo.activeSkills);
    let lastError: Error | null = null;

    this._isInRetryLoop = true;
    for (const providerIndex of getAttemptOrder(
      activeProviders.length,
      providers.startingAvailableProviderIndex,
    )) {
      const provider = activeProviders[providerIndex];

      agent.replaceMessages(baseMessages.slice());
      agent.state.error = undefined;
      this.agentInfo.activeSkills = cloneActiveSkills(baseSkills);

      let model;
      try {
        model = resolveModel(provider);
      } catch (error) {
        lastError = error instanceof Error ? error : new Error(String(error));
        logger.warn(
          `[Agent] Invalid model config (${provider.provider}, ${provider.model}): `,
          error,
        );
        continue;
      }

      let resolvedApiKey = provider.apiKey;
      if (provider.authType === "oauth" || isOAuthProvider(provider.provider)) {
        const oauthKey = await resolveApiKey(provider);
        if (!oauthKey) {
          lastError = new Error(
            `OAuth token not available for ${provider.provider}. Please log in first.`,
          );
          logger.warn(
            `[Agent] No OAuth token for ${provider.provider}, skipping.`,
          );
          continue;
        }
        resolvedApiKey = oauthKey;
        logger.info(`[Agent] OAuth token resolved for ${provider.provider}.`);
      }

      this.resolvedApiKey = resolvedApiKey;
      onProgress?.(
        activeProviders.length > 1
          ? t("agent.progress.using_model", { provider: provider.provider })
          : t("agent.progress.thinking"),
      );
      agent.setModel(model);
      agent.setSystemPrompt(systemPrompt);
      agent.setThinkingLevel("medium");
      await this.preloadCurrentAppSkill();
      await this.refreshRuntimeTools();

      let responseText = "";
      const unsubscribe = agent.subscribe((event) => {
        if (
          event.type === "message_update" &&
          event.assistantMessageEvent.type === "text_delta"
        ) {
          responseText += event.assistantMessageEvent.delta;
        }
        if (event.type === "tool_execution_start") {
          switch (event.toolName) {
            case "read_skill":
              onProgress?.(t("tool.progress.read_skill"));
              break;
            case "execute_bash":
              onProgress?.(t("tool.progress.execute_bash"));
              break;
            case "sleep":
              onProgress?.(t("tool.progress.sleep"));
              break;
            case "update_core_memory":
              onProgress?.(t("tool.progress.update_core_memory"));
              break;
            case "append_daily_memory":
              onProgress?.(t("tool.progress.append_daily_memory"));
              break;
            case "list_schedules":
              onProgress?.(t("tool.progress.list_schedules"));
              break;
            case "register_schedule":
            case "register_one_off_schedule":
              onProgress?.(t("tool.progress.register_schedule"));
              break;
            case "delete_schedule":
              onProgress?.(t("tool.progress.delete_schedule"));
              break;
            default:
              onProgress?.(
                t("tool.progress.default", { toolName: event.toolName }),
              );
              break;
          }
        }
        if (
          event.type === "tool_execution_end" &&
          event.toolName === "read_skill" &&
          !event.isError
        ) {
          this.agentInfo.activeSkills = mergeActiveSkill(
            this.agentInfo.activeSkills,
            event.result?.details,
          );
          this.refreshRuntimeToolsSync();
          const skillName =
            typeof event.result?.details?.name === "string"
              ? event.result.details.name
              : "unknown";
          logger.info(`[Agent] Applying skill instructions: ${skillName}`);
          onProgress?.(t("agent.progress.applying_skill", { skillName }));
        }
      });

      try {
        await agent.prompt(userMessage);
      } catch (error) {
        lastError = error instanceof Error ? error : new Error(String(error));
        unsubscribe();
        if (
          lastError.name === "AbortError" ||
          lastError.message?.toLowerCase().includes("abort")
        ) {
          logger.info(
            `[Agent] Inference aborted by user for ${provider.provider}. Stopping retry.`,
          );
          break;
        }
        onProgress?.(t("agent.progress.retrying"));
        logger.warn(
          `❌ [Agent] Provider ${provider.provider} threw before completion: ${lastError.message}`,
        );
        continue;
      }

      unsubscribe();

      if (agent.state.error) {
        lastError = new Error(agent.state.error);
        if (String(agent.state.error).toLowerCase().includes("abort")) {
          logger.info(
            `[Agent] Inference aborted (state.error) for ${provider.provider}. Stopping retry.`,
          );
          break;
        }
        onProgress?.(t("agent.progress.retrying"));
        logger.warn(
          `❌ [Agent] Provider ${provider.provider} failed: ${agent.state.error}. Trying next provider if available.`,
        );
        continue;
      }

      if (!responseText) {
        responseText = extractFinalResponseText(agent);
      }

      logger.info(
        `✅ [Agent] Response success (${provider.provider}/${provider.model})`,
      );
      this.currentProvider = provider.provider;
      this.currentModel = provider.model;
      this.resetTurnScopedSkills();
      return {
        responseText,
        lastError: null,
        success: true,
      };
    }

    this._isInRetryLoop = false;
    agent.replaceMessages(baseMessages);
    agent.state.error = undefined;
    this.agentInfo.activeSkills = baseSkills;
    this.resetTurnScopedSkills();

    const isAborted =
      !!lastError &&
      (lastError.name === "AbortError" ||
        lastError.message?.toLowerCase().includes("abort"));

    // 모든 프로바이더가 실패했고 아직 request가 finalize되지 않은 경우 직접 에러를 브로드캐스트
    if (this.currentPendingResponse && !isAborted) {
      const rawMsg = lastError?.message ?? "";
      const parsedMsg = parseProviderErrorMessage(rawMsg);
      const errorMsg = parsedMsg
        ? t("agent.error.all_providers_failed", { message: parsedMsg })
        : t("agent.error.no_providers");
      this.finalizeCurrentRequest(errorMsg, true);
    }

    return {
      responseText: "",
      lastError,
      success: false,
      aborted: isAborted,
    };
  }
}
