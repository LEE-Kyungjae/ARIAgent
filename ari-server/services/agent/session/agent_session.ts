import { Agent } from "@mariozechner/pi-agent-core";
import { AgentInfo } from "../../../models/agent.js";
import { AIProviders } from "../../../models/settings.js";
import { PendingAgentResponse } from "../../../models/agent_response.js";
import { appendChatLog } from "../../../repositories/chat_log_repository.js";
import { appendUsageLog } from "../../../repositories/usage_repository.js";
import { pushApp, errorApp } from "../../../protocol/app.js";
import { sendAgentRequest, sendAgentCancel } from "../../../protocol/agent.js";
import {
  extractFinalResponseText,
  extractTextFromAgentMessage,
} from "../pipeline/response_parser.js";
import {
  getAttemptOrder,
  isOAuthProvider,
  resolveApiKey,
  resolveModel,
} from "../provider/selector.js";
import { cloneActiveSkills, mergeActiveSkill } from "./active_skills.js";
import { loadSkillsForPrompt } from "../../../skills/index.js";
import {
  buildSessionTools,
  buildSessionToolsSync,
} from "./runtime_tools.js";
import { logger } from "../../../infra/logger.js";
import { t } from "../../../infra/i18n.js";
import { getSettings } from "../../../repositories/setting_repository.js";
import { Settings } from "../../../models/settings.js";
import {
  resolveForwardIfPending,
  rejectForwardIfPending,
} from "../pipeline/inter_agent.js";
import { markAgentIdle, markAgentWorking } from "./activity_state.js";

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
  /** skip_turn 도구 호출됨 — 응답 송신·기록 모두 억제하고 thinking UI 만 정리. */
  currentSkipped = false;
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

  /** skip_turn 도구가 호출되면 set. agent_end 에서 handleSkipped 로 분기. */
  markSkipped(): void {
    this.currentSkipped = true;
  }

  private handleSkipped(): void {
    const pending = this.currentPendingResponse;
    this.currentPendingResponse = null;
    this.currentRequestAnnounced = false;
    this.currentResponseText = "";
    this.currentSkipped = false;

    if (!pending) return;

    const idx = this.pendingResponses.findIndex(
      (p) => p.requestId === pending.requestId,
    );
    if (idx !== -1) this.pendingResponses.splice(idx, 1);

    // skip 응답은 빈 문자열로 waiter resolve (호출자가 timeout 으로 안 빠지게).
    this.resolveRequestWaiter(pending.requestId, "");
    resolveForwardIfPending(pending.requestId, "");
    markAgentIdle(pending.agentId);

    // chat log append X, push X. 클라 thinking 시스템 메시지만 정리.
    const cancelPayload = {
      agentId: pending.agentId,
      requestId: pending.requestId,
    };
    if (pending.dispatchMode === "ari-broadcast") {
      sendAgentCancel({ appId: "ari" }, cancelPayload);
    } else if (pending.originUuid) {
      sendAgentCancel({ uuid: pending.originUuid }, cancelPayload);
    }
  }

  private shouldBroadcastPending(pending: PendingAgentResponse): boolean {
    // 소켓 origin 이 없으면 task (스케줄러 등 서버 내부 발행).
    // SHOW_TASK_MESSAGES 설정에 따라 로그·브로드캐스트 여부 결정.
    if (pending.originUuid) return true;
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
      const meta = this._pendingMeta;
      this._pendingMeta = null;

      // dispatchMode 별 assistant 응답 chat log 기록.
      // (user 메시지는 orchestrator.submitAgentRequest 진입 시점에 이미 append 됨.)
      // - ari-broadcast: SARI 자기 1:1 history 에는 안 적고, PM history (ari__default) 에만
      //   어시스턴트 메시지로 append → ari 채팅창 재부팅 후에도 복원됨.
      // - 그 외 (user/inter): 자기 (appId, agentId) chat log 에 assistant append.
      if (pending.dispatchMode === "ari-broadcast") {
        // TODO: PM agentId 가 "default" 가 아닌 환경 대응 시 forward payload 에
        // caller 정보 (appId, agentId) 를 실어 보내 사용.
        appendChatLog("ari", "default", {
          type: "chat",
          isUser: false,
          message: responseText,
          requestId: pending.requestId,
          from: pending.toAppId,
          to: "ari",
          senderName: pending.senderName,
        });
      } else {
        appendChatLog(pending.appId, pending.agentId, {
          type: "chat",
          isUser: false,
          message: responseText,
          requestId: pending.requestId,
          ...(pending.dispatchMode === "inter"
            ? {
                from: pending.toAppId,
                to: pending.fromAppId,
                senderName: pending.senderName,
              }
            : {}),
        });
      }

      if (meta && (meta.usage?.totalTokens ?? 0) > 0) {
        appendUsageLog(pending.agentId, {
          requestId: pending.requestId,
          provider: meta.provider,
          model: meta.model,
          usage: meta.usage,
        });
      }

      // dispatchMode 별 응답 송신.
      if (isError) {
        if (pending.dispatchMode === "ari-broadcast") {
          // ari-broadcast 모드 에러: originUuid 가 없어도 ari 채팅창에
          // 에러 보고를 보내야 isLoading 이 풀린다 (스케줄러 발 task 등).
          errorApp({ appId: "ari" }, {
            ok: false,
            data: {
              message: responseText,
              requestId: pending.requestId,
              agentId: pending.agentId,
              appId: pending.appId,
              senderName: pending.senderName,
            },
          });
        } else if (pending.originUuid) {
          errorApp({ uuid: pending.originUuid }, {
            ok: false,
            data: {
              message: responseText,
              requestId: pending.requestId,
              agentId: pending.agentId,
              appId: pending.appId,
              senderName: pending.senderName,
            },
          });
        }
        rejectForwardIfPending(
          pending.requestId,
          new Error(responseText || "inter-agent error"),
        );
      } else if (pending.dispatchMode === "ari-broadcast") {
        // ari 방 팬아웃 응답: ari 채팅창에만 표시. sari 1:1 채팅창은 깨끗 유지.
        pushApp({ appId: "ari" }, {
          ok: true,
          data: {
            response: responseText,
            requestId: pending.requestId,
            agentId: pending.agentId,
            appId: pending.appId,
            from: pending.toAppId,
            to: "ari",
            senderName: pending.senderName,
          },
        });
        resolveForwardIfPending(pending.requestId, responseText);
      } else if (pending.dispatchMode === "inter") {
        // PM↔도메인 직접 위임 (control_app 등): 양쪽 채팅창에 어시스턴트 버블 표시.
        if (pending.originUuid) {
          pushApp({ uuid: pending.originUuid }, {
            ok: true,
            data: {
              response: responseText,
              message: responseText,
              requestId: pending.requestId,
              agentId: pending.agentId,
              appId: pending.appId,
              from: pending.toAppId,
              to: pending.fromAppId,
              senderName: pending.senderName,
            },
          });
        }
        if (pending.toAppId) {
          pushApp({ appId: pending.toAppId }, {
            ok: true,
            data: {
              response: responseText,
              requestId: pending.requestId,
              agentId: pending.agentId,
              appId: pending.appId,
              from: pending.toAppId,
              to: pending.fromAppId,
              senderName: pending.senderName,
            },
          });
        }
        // control_app (`message` 모드) 에서 걸어둔 forward 대기를 해제한다.
        resolveForwardIfPending(pending.requestId, responseText);
      } else {
        // "user": 일반 사용자 요청 — 호출자 소켓에 응답.
        // 스케줄러 발 (originUuid 없음) 의 PM 응답은 ari 소켓에 fallback push
        // → ari 채팅창에 task 결과가 자연스럽게 뜸.
        if (pending.originUuid) {
          pushApp({ uuid: pending.originUuid }, {
            ok: true,
            data: {
              response: responseText,
              requestId: pending.requestId,
              agentId: pending.agentId,
              appId: pending.appId,
              senderName: pending.senderName,
            },
          });
        } else if (pending.appId === "ari") {
          pushApp({ appId: "ari" }, {
            ok: true,
            data: {
              response: responseText,
              requestId: pending.requestId,
              agentId: pending.agentId,
              appId: pending.appId,
              senderName: pending.senderName,
            },
          });
        }
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
          });
          // dispatchMode 별 /AGENT.REQUEST 에코.
          // - "user":          originUuid 에만 (사용자 채팅창에 자기 입력 표시).
          // - "inter":         originUuid + 대상 앱 소켓 (양쪽 채팅창에 표시).
          // - "ari-broadcast": 에코 없음 (sari 1:1 깨끗 유지, ari 채팅창엔 이미 사용자 입력 표시됨).
          const requestPayload = {
            message: pending.originalMessage,
            requestId: pending.requestId,
            agentId: pending.agentId,
            appId: pending.appId,
            senderName: pending.senderName,
          };
          if (pending.dispatchMode === "user" && pending.originUuid) {
            sendAgentRequest({ uuid: pending.originUuid }, requestPayload);
          } else if (pending.dispatchMode === "inter") {
            if (pending.originUuid) {
              sendAgentRequest({ uuid: pending.originUuid }, requestPayload);
            }
            if (pending.toAppId) {
              sendAgentRequest(
                { appId: pending.toAppId },
                {
                  ...requestPayload,
                  from: pending.fromAppId,
                  to: pending.toAppId,
                },
              );
            }
          }
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
        // skip_turn 도구 호출로 인한 abort — chat log/push 억제 + thinking 정리.
        if (this.currentSkipped) {
          this.handleSkipped();
          return;
        }
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

    const isAborted =
      !!lastError &&
      (lastError.name === "AbortError" ||
        lastError.message?.toLowerCase().includes("abort"));

    // 취소돼도 유저 메시지는 in-memory 히스토리에 남겨야 다음 턴에서 기억됨.
    // 정상 실패(프로바이더 전부 실패 등)는 기존처럼 baseMessages 로 롤백.
    if (isAborted) {
      const userMsg = {
        role: "user",
        content: [{ type: "text", text: userMessage }],
        timestamp: Date.now(),
      } as any;
      agent.replaceMessages([...baseMessages, userMsg]);
    } else {
      agent.replaceMessages(baseMessages);
    }
    agent.state.error = undefined;
    this.agentInfo.activeSkills = baseSkills;
    this.resetTurnScopedSkills();

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
