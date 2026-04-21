import { AgentMessage } from "@mariozechner/pi-agent-core";
import { getSettings } from "../../repositories/setting_repository.js";
import { getAgentsConfig } from "../../repositories/agent_repository.js";
import { appendChatLog, readRecentUserMessages } from "../../repositories/chat_log_repository.js";
import { AgentInfo, AgentsConfig } from "../../models/agent.js";
import {
  ChatWithAgentResult,
  PendingAgentResponse,
} from "../../models/agent_response.js";
import {
  Settings,
  AIProviderConfig,
  AIProviders,
  AvailablePlugins,
} from "../../models/settings.js";
import { logger } from "../../infra/logger.js";
import { buildSystemPrompt, pruneContext } from "./context_builder.js";
import { extractFinalResponseText } from "./response_parser.js";
import { getOAuthStatus } from "../oauth/index.js";
import { Prompt } from "../../infra/prompt.js";
import { runWithExecutionContext } from "./execution_context.js";
import {
  clearAgentSession,
  clearAllAgentSessions,
  getOrCreateSession,
  getSession,
  listAgentSessions,
} from "./session_manager.js";
import {
  clearSkillCache,
  loadAvailableApps,
  loadAvailableSkills,
  loadSkillsForPrompt,
} from "../tools/skill_registry.js";
import { clearToolCache, loadMainTools } from "../tools/tool_registry.js";
import { isOAuthProvider, ARI_CLOUD_PROVIDER } from "./provider_selector.js";
import { UserSocketHandler } from "../../system/ws.js";
import { loadAllApps } from "../../skills/index.js";
import { readRecentDailyLogs } from "../memory.js";

// 에이전트 간 전달 체인 기본 TTL. `/AGENT` 에 ttl 미지정 시 적용.
const DEFAULT_INTER_AGENT_TTL = 5;

const agentState = new AIProviders();
let currentTools = [] as Awaited<ReturnType<typeof loadMainTools>>;
let currentSkills = [] as Awaited<ReturnType<typeof loadAvailableSkills>>;

function getSessionForAgent(agentProfile: AgentInfo) {
  return getOrCreateSession(
    agentProfile,
    agentState,
    pruneContext,
    (provider, error) => {
      logger.warn(
        `[Agent] Invalid model config (${provider.provider}, ${provider.model}): `,
        error,
      );
    },
  );
}

type ExecuteAgentRequestParams = {
  message: string;
  requestId: string;
  agentId?: string;
  persona?: string;
  avatarName?: string;
  platform?: string;
  appId?: string;
  socketAppId?: string;
  details?: Record<string, unknown>;
  waitForCompletion?: boolean;
  /** 요청을 보낸 소켓 uuid. 응답 라우팅 타겟. 없으면 task (스케줄러) 기원. */
  originUuid?: string;
  /** 에이전트 간 라우팅 raw 입력. `resolveInterAgentTarget` 가 해석한다. */
  from?: string;
  to?: string;
  /** 에이전트 간 잔여 TTL. `<= 0` 이면 reject (loop 방지). */
  ttl?: number;
};

/**
 * `/AGENT` 라우팅 메타 해석.
 * - `to`: 대상 에이전트 appId (생략 시 sender 자기 자신).
 * - `from`: 발신 appId (생략 시 socketAppId).
 */
function resolveInterAgentTarget(
  params: { from?: string; to?: string },
  socketAppId?: string,
): { targetAgentId: string; fromAppId?: string; toAppId?: string } {
  const fromAppId = params.from?.trim() || socketAppId || undefined;
  const explicitTo = params.to?.trim();
  const toAppId = explicitTo || fromAppId;

  const targetAgentId =
    toAppId || getAgentsConfig(new AgentsConfig()).selected || "default";

  return { targetAgentId, fromAppId, toAppId };
}

function isRequestCancellationError(error: unknown): boolean {
  if (!(error instanceof Error)) {
    return false;
  }

  const message = error.message.toLowerCase();
  return (
    message.includes("request aborted") ||
    message.includes("request queue reset")
  );
}

export async function initAgent(providersConfig?: AIProviders): Promise<void> {
  const globalSettings = getSettings(new Settings()) || {};
  const state = agentState;

  clearToolCache();
  clearSkillCache();
  currentTools = await loadMainTools();
  currentSkills = await loadSkillsForPrompt();

  if (providersConfig && providersConfig.providers.length > 0) {
    state.setProviders(providersConfig.providers);
  } else if (globalSettings.PROVIDERS && globalSettings.PROVIDERS.length > 0) {
    state.setProviders(globalSettings.PROVIDERS);
  } else {
    const defaultProvider = globalSettings.PROVIDER || "openai-codex";
    state.setProviders([
      new AIProviderConfig({
        provider: defaultProvider,
        model: globalSettings.OPENAI_MODEL || "gpt-5.3-codex",
        apiKey: globalSettings.OPENAI_API_KEY || "",
        authType: defaultProvider === "openai-codex" ? "oauth" : "apikey",
      }),
    ]);
  }
  const active =
    state.providers.find((provider) => !!provider.apiKey) || state.providers[0];
  state.currentModel =
    active?.model || globalSettings.OPENAI_MODEL || "gpt-5.3-codex";
  state.currentProvider =
    active?.provider || globalSettings.PROVIDER || "openai-codex";

  state.setAvailableProviders(
    (state.providers || []).filter((provider: AIProviderConfig) => {
      if (provider.apiKey) return true;
      if (provider.authType === "oauth" || isOAuthProvider(provider.provider)) {
        const oauthStatus = getOAuthStatus(provider.accountId);
        if (!oauthStatus.loggedIn) {
          logger.warn(
            `[Agent] OAuth provider ${provider.provider} (${provider.accountId}) is not logged in. Skipping.`,
          );
          return false;
        }
        return true;
      }
      return false;
    }),
  );
  clearAllAgentSessions();

  if (state.availableProviders.length === 0) {
    // 사용 가능한 프로바이더가 없으면 ARICloud 프록시를 통한 setup agent 모드로 전환
    const cloudSetupProvider = new AIProviderConfig({
      provider: ARI_CLOUD_PROVIDER,
      model: "gpt-4.1-mini",
      apiKey: "ari-cloud",
      authType: "apikey",
    });
    state.setAvailableProviders([cloudSetupProvider]);
    state.currentProvider = ARI_CLOUD_PROVIDER;
    state.currentModel = "gpt-4.1-mini";
    logger.info(
      "🌐 Setup 모드 — ARICloud 프록시를 통해 앱 사용 가이드 에이전트가 활성화됩니다.",
    );
    return;
  }

  logger.info(
    `✅ Agent initialized. (${state.availableProviders.length} providers loaded, current: ${state.currentProvider}/${state.currentModel})`,
  );
}

export function getCurrentState() {
  return agentState;
}

export async function getPluginsInfo(): Promise<AvailablePlugins> {
  getSettings(new Settings());
  if (currentTools.length === 0) {
    currentTools = await loadMainTools();
  }
  const [skills, apps] = await Promise.all([
    loadAvailableSkills(),
    loadAvailableApps(),
  ]);
  return { tools: currentTools, skills, apps };
}

export async function chatWithAgent(
  message: string,
  agentProfile: AgentInfo = new AgentInfo(),
  onProgress?: (message: string) => void,
  pendingResponse?: PendingAgentResponse,
): Promise<ChatWithAgentResult> {
  const currentAgentId =
    agentProfile.id ||
    getAgentsConfig(new AgentsConfig()).selected ||
    "default";
  const currentAgentProfile = new AgentInfo({
    ...agentProfile,
    id: currentAgentId,
  });

  if (agentState.availableProviders.length === 0) {
    return {
      responseText: `[에코 모드] "${message}"\n\n⚠️ Settings에서 하나 이상의 AI Provider API Key를 추가하세요.`,
    };
  }

  if (currentTools.length === 0) {
    currentTools = await loadMainTools();
  }

  currentSkills = await loadAvailableSkills();

  const session = getSessionForAgent(currentAgentProfile);
  session.agentInfo.availableSkills = currentSkills;
  session.ensureLifecycleAttached();
  if (pendingResponse) {
    session.enqueueRequest(pendingResponse);
  }

  const systemPrompt = await buildSystemPrompt(session.agentInfo, agentState, message);
  const result = await runWithExecutionContext(
    {
      agentId: currentAgentId,
      appId: currentAgentProfile.appId,
      ttl: pendingResponse?.ttl,
    },
    () =>
      session.runInference(
        message,
        systemPrompt,
        agentState,
        onProgress,
      ),
  );

  if (!result.success) {
    if (result.aborted) {
      return { responseText: "", aborted: true };
    }

    if (result.lastError) {
      return {
        responseText: `❌ 모든 프로바이더에서 오류가 발생했습니다: ${result.lastError.message}`,
      };
    }

    return {
      responseText: "❌ 사용 가능한 프로바이더가 없습니다.",
    };
  }

  return {
    responseText:
      result.responseText ||
      extractFinalResponseText(session.agent) ||
      "처리 중 오류가 발생했습니다.",
  };
}

export async function submitAgentRequest(
  message: string,
  agentProfile: AgentInfo,
  onProgress: ((message: string) => void) | undefined,
  pendingResponse: PendingAgentResponse,
): Promise<{ status: "follow_up" | "broadcasted" | "cancelled" }> {
  const agentId = pendingResponse.agentId || agentProfile.id || "default";
  const currentAgentProfile = new AgentInfo({
    ...agentProfile,
    id: agentId,
  });

  if (agentState.availableProviders.length === 0) {
    const responseText = `[에코 모드] "${message}"\n\n⚠️ Settings에서 하나 이상의 AI Provider API Key를 추가하세요.`;
    UserSocketHandler.sendToOrigin(
      pendingResponse.originUuid,
      "/AGENT.REQUEST",
      {
        message: pendingResponse.originalMessage,
        requestId: pendingResponse.requestId,
      },
    );
    appendChatLog(pendingResponse.appId, agentId, {
      type: "chat",
      isUser: true,
      message: pendingResponse.originalMessage,
      requestId: pendingResponse.requestId,
    });
    appendChatLog(pendingResponse.appId, agentId, {
      type: "chat",
      isUser: false,
      message: responseText,
      requestId: pendingResponse.requestId,
    });
    UserSocketHandler.sendToOrigin(
      pendingResponse.originUuid,
      "/APP.PUSH",
      {
        ok: true,
        data: {
          response: responseText,
          requestId: pendingResponse.requestId,
          appId: pendingResponse.appId,
        },
      },
    );
    return { status: "broadcasted" };
  }

  const session = getSessionForAgent(currentAgentProfile);
  session.ensureLifecycleAttached();
  session.enqueueRequest(pendingResponse);

  if (session.agent.state.isStreaming) {
    session.agent.followUp({
      role: "user",
      content: [{ type: "text", text: message }],
      timestamp: Date.now(),
    } as AgentMessage);
    UserSocketHandler.sendToOrigin(
      pendingResponse.originUuid,
      "/AGENT.FOLLOW_UP",
      {
        ok: true,
        data: {
          requestId: pendingResponse.requestId,
          message: pendingResponse.originalMessage,
          agentId,
          reason: "busy",
        },
      },
    );
    logger.info(
      `[Agent] Follow-up queued for ${agentId} (${pendingResponse.requestId})`,
    );
    return { status: "follow_up" };
  }

  if (
    session.currentPendingResponse &&
    session.currentPendingResponse.requestId !== pendingResponse.requestId
  ) {
    logger.warn(
      `[Agent] Clearing stale current pending request for ${agentId}: ${session.currentPendingResponse.requestId}`,
    );
    session.currentPendingResponse = null;
  }

  const stalePendingRequests = session.pendingResponses.filter(
    (item) => item.requestId !== pendingResponse.requestId,
  );
  if (stalePendingRequests.length > 0) {
    logger.warn(
      `[Agent] Clearing ${stalePendingRequests.length} stale pending request(s) before immediate execution for ${agentId}.`,
    );
    session.pendingResponses = session.pendingResponses.filter(
      (item) => item.requestId === pendingResponse.requestId,
    );
  }

  session.beginNextRequest();
  const result = await chatWithAgent(message, agentProfile, onProgress, pendingResponse);

  if (result.aborted) {
    session.removeRequest(pendingResponse.requestId);
    return { status: "cancelled" };
  }

  return { status: "broadcasted" };
}

export async function submitAgentRequestAndWait(
  message: string,
  agentProfile: AgentInfo,
  onProgress: ((message: string) => void) | undefined,
  pendingResponse: PendingAgentResponse,
): Promise<{
  status: "follow_up" | "broadcasted" | "cancelled";
  responseText?: string;
}> {
  const agentId = pendingResponse.agentId || agentProfile.id || "default";
  const currentAgentProfile = new AgentInfo({
    ...agentProfile,
    id: agentId,
  });

  if (agentState.availableProviders.length === 0) {
    const result = await submitAgentRequest(
      message,
      currentAgentProfile,
      onProgress,
      pendingResponse,
    );
    return {
      status: result.status,
      responseText: `[에코 모드] "${message}"\n\n⚠️ Settings에서 하나 이상의 AI Provider API Key를 추가하세요.`,
    };
  }

  const session = getSessionForAgent(currentAgentProfile);
  session.ensureLifecycleAttached();
  const completion = session
    .waitForRequestCompletion(pendingResponse.requestId)
    .then((responseText) => ({ status: "completed" as const, responseText }))
    .catch((error) => {
      if (isRequestCancellationError(error)) {
        return { status: "cancelled" as const };
      }
      throw error;
    });

  try {
    const result = await submitAgentRequest(
      message,
      currentAgentProfile,
      onProgress,
      pendingResponse,
    );

    if (result.status === "cancelled") {
      return { status: "cancelled" };
    }

    const completionResult = await completion;
    if (completionResult.status === "cancelled") {
      return { status: "cancelled" };
    }

    return {
      status: result.status,
      responseText: completionResult.responseText,
    };
  } catch (error) {
    if (isRequestCancellationError(error)) {
      return { status: "cancelled" };
    }
    dropPendingResponse(agentId, pendingResponse.requestId);
    throw error;
  }
}

export async function executeAgentRequest(
  params: ExecuteAgentRequestParams,
): Promise<{
  status: "follow_up" | "broadcasted" | "cancelled";
  requestId: string;
  agentId: string;
  responseText?: string;
}> {
  const {
    message: originalMessage,
    requestId,
    persona = "",
    avatarName = "",
    platform = "",
    agentId,
    appId,
    socketAppId,
    details,
    waitForCompletion = false,
    originUuid,
    from,
    to,
    ttl,
  } = params;

  let message = originalMessage;
  const resolved = resolveInterAgentTarget({ from, to }, socketAppId);
  const fromAppId = resolved.fromAppId;
  const toAppId = resolved.toAppId;
  const currentAgentId = agentId || resolved.targetAgentId;

  // 루프 방지: TTL 소진 시 거부. 미지정 시 기본값 적용.
  const isInterAgent = !!(fromAppId && toAppId && fromAppId !== toAppId);
  const effectiveTtl =
    typeof ttl === "number" && Number.isFinite(ttl) ? ttl : DEFAULT_INTER_AGENT_TTL;
  if (isInterAgent && effectiveTtl <= 0) {
    logger.warn(
      `[Agent] Rejected inter-agent request: ttl=${effectiveTtl} (${fromAppId} → ${toAppId})`,
    );
    throw new Error(`Inter-agent TTL exhausted (${effectiveTtl})`);
  }

  // 페르소나/아바타명은 메시지 페이로드로만 흘러온다 (단일 원칙).
  // 발신자(소켓) 쪽에서 자기 페르소나를 읽어 /AGENT 에 실어 보낸다.
  const effectivePersona = persona;
  const effectiveAvatarName = avatarName || "ARI";
  const normalizedPlatform =
    typeof platform === "string" ? platform.trim() : "";
  let resolvedAppId =
    (typeof appId === "string" ? appId.trim() : "") ||
    socketAppId ||
    undefined;

  if (!message) {
    throw new Error("message required");
  }

  if (!resolvedAppId && normalizedPlatform) {
    const apps = await loadAllApps();
    if (apps.some((entry) => entry.name === normalizedPlatform)) {
      resolvedAppId = normalizedPlatform;
    }
  }

  const detailEntries =
    details && typeof details === "object" && !Array.isArray(details)
      ? Object.entries(details)
          .filter(([, value]) => value != null)
          .map(([key, value]) => ({
            key,
            value:
              typeof value === "string" ? value : JSON.stringify(value),
          }))
      : [];

  const connectedAppIds = UserSocketHandler.getConnectedAppIds();
  const recentDailyLogs = readRecentDailyLogs(currentAgentId);
  const recentUserMessages = readRecentUserMessages(resolvedAppId, currentAgentId, 5);

  message = await Prompt.load("app_user_context.hbs", {
    now_str: new Date().toISOString(),
    currentAppId: resolvedAppId,
    platform: normalizedPlatform,
    details: detailEntries,
    connectedAppIds: !resolvedAppId && connectedAppIds.length > 0 ? connectedAppIds : undefined,
    recentDailyLogs: recentDailyLogs || undefined,
    recentUserMessages: recentUserMessages.length > 0 ? recentUserMessages : undefined,
    message,
  });

  const agentProfile = new AgentInfo({
    id: currentAgentId,
    name: effectiveAvatarName,
    persona: effectivePersona,
    platform: normalizedPlatform,
    appId: resolvedAppId,
  });

  // 에이전트 간 호출이면 대상(`toAppId`) 소켓에도 팬아웃하여
  // 해당 앱 채팅창이 자기 세션의 "생각 중" 진행도를 볼 수 있게 함.
  const onProgress = (progressMessage: string) => {
    const payload = {
      ok: true,
      data: {
        requestId,
        agentId: currentAgentId,
        appId: resolvedAppId,
        message: progressMessage,
      },
    };
    UserSocketHandler.sendToOrigin(originUuid, "/AGENT.PROGRESS", payload);
    if (isInterAgent && toAppId) {
      UserSocketHandler.send({ appId: toAppId }, "/AGENT.PROGRESS", payload);
    }
  };

  const pendingResponse: PendingAgentResponse = {
    requestId,
    agentId: currentAgentId,
    originalMessage,
    appId: resolvedAppId,
    // 원본 소켓. 없으면 task (스케줄러) 기원 — 응답은 drop.
    originUuid,
    // 에이전트 간 라우팅 메타. 응답 채널 분기에 사용.
    fromAppId,
    toAppId,
    isInterAgent,
    ttl: effectiveTtl,
  };

  if (waitForCompletion) {
    const result = await submitAgentRequestAndWait(
      message,
      agentProfile,
      onProgress,
      pendingResponse,
    );
    return {
      status: result.status,
      requestId,
      agentId: currentAgentId,
      responseText: result.responseText,
    };
  }

  const result = await submitAgentRequest(
    message,
    agentProfile,
    onProgress,
    pendingResponse,
  );
  return {
    status: result.status,
    requestId,
    agentId: currentAgentId,
  };
}

export function dropPendingResponse(agentId: string, requestId: string): void {
  const session = getSession(agentId);
  if (!session) {
    return;
  }

  session.removeRequest(requestId);
}

export function clearAgentInstance(agentId: string) {
  clearAgentSession(agentId);
  logger.info(`[Agent] Instance cleared for: ${agentId}`);
}

export function abortAgent(agentId: string) {
  const session = getSession(agentId);
  if (session && session.agent) {
    session.agent.clearAllQueues();
    session.resetRequestQueue();
    session.agent.abort();
    logger.info(`[Agent] Thinking aborted for: ${agentId}`);
  } else {
    logger.warn(`[Agent] No active session to abort for: ${agentId}`);
  }
}

/**
 * 소켓 종료 시 해당 소켓이 발행한 진행 중 요청을 abort.
 * originUuid 가 일치하는 세션을 찾아 abort + 큐 정리.
 * 반환값은 abort 된 agentId 목록 (로깅용).
 */
export function abortAgentsForOrigin(originUuid: string): string[] {
  const aborted: string[] = [];
  for (const { agentId, session } of listAgentSessions()) {
    const pending = session.currentPendingResponse;
    if (pending?.originUuid !== originUuid) continue;
    if (session.agent) {
      session.agent.clearAllQueues();
      session.resetRequestQueue();
      session.agent.abort();
    }
    aborted.push(agentId);
  }
  return aborted;
}

export function canCancelAgent(
  agentId: string,
  requesterUuid: string,
  requesterAppId?: string,
): boolean {
  const session = getSession(agentId);
  if (!session) return true;
  const pending = session.currentPendingResponse;
  if (!pending) return true;
  if (pending.originUuid) {
    return pending.originUuid === requesterUuid;
  }
  return requesterAppId === "ari";
}
