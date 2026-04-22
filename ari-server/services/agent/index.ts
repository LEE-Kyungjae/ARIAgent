import { getAgentsConfig } from "../../repositories/agent_repository.js";
import { AgentInfo, AgentsConfig } from "../../models/agent.js";
import {
  ChatWithAgentResult,
  PendingAgentResponse,
} from "../../models/agent_response.js";
import { logger } from "../../infra/logger.js";
import { buildSystemPrompt, pruneContext } from "./context_builder.js";
import { extractFinalResponseText } from "./response_parser.js";
import { runWithExecutionContext } from "./execution_context.js";
import { getOrCreateSession } from "./session_manager.js";
import { loadAllSkills } from "../../skills/index.js";
import { loadMainTools } from "../../tools/index.js";

import {
  DEFAULT_INTER_AGENT_TTL,
  isRequestCancellationError,
  resolveInterAgentTarget,
} from "./inter_agent.js";
import { createProgressFanout } from "./progress_fanout.js";
import {
  composeUserMessage,
  normalizeDetailEntries,
  resolveAppIdFromPlatform,
} from "./request_builder.js";
import {
  agentState,
  getCurrentSkills,
  getCurrentTools,
  setCurrentSkills,
  setCurrentTools,
} from "./bootstrap.js";
import {
  broadcastEchoResponse,
  buildEchoMessage,
  isEchoMode,
} from "./echo_mode.js";
import {
  applyFollowUp,
  clearStaleRequests,
  decideQueueAction,
} from "./queue_router.js";
export {
  getCurrentState,
  getPluginsInfo,
  initAgent,
} from "./bootstrap.js";
export {
  abortAgent,
  abortAgentsForOrigin,
  canCancelAgent,
  clearAgentInstance,
  dropPendingResponse,
} from "./control.js";
import { dropPendingResponse } from "./control.js";

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

  if (isEchoMode()) {
    return { responseText: buildEchoMessage(message) };
  }

  if (getCurrentTools().length === 0) {
    setCurrentTools(await loadMainTools());
  }

  setCurrentSkills(await loadAllSkills());

  const session = getSessionForAgent(currentAgentProfile);
  session.agentInfo.availableSkills = getCurrentSkills();
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

  if (isEchoMode()) {
    broadcastEchoResponse(message, agentId, pendingResponse);
    return { status: "broadcasted" };
  }

  const session = getSessionForAgent(currentAgentProfile);
  session.ensureLifecycleAttached();
  session.enqueueRequest(pendingResponse);

  if (decideQueueAction(session) === "follow_up") {
    applyFollowUp(session, message, agentId, pendingResponse);
    return { status: "follow_up" };
  }

  clearStaleRequests(session, pendingResponse.requestId, agentId);
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

  if (isEchoMode()) {
    const result = await submitAgentRequest(
      message,
      currentAgentProfile,
      onProgress,
      pendingResponse,
    );
    return {
      status: result.status,
      responseText: buildEchoMessage(message),
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

  if (!message) {
    throw new Error("message required");
  }

  // 페르소나/아바타명은 메시지 페이로드로만 흘러온다 (단일 원칙).
  // 발신자(소켓) 쪽에서 자기 페르소나를 읽어 /AGENT 에 실어 보낸다.
  const effectivePersona = persona;
  const effectiveAvatarName = avatarName || "ARI";
  const normalizedPlatform =
    typeof platform === "string" ? platform.trim() : "";
  const resolvedAppId = await resolveAppIdFromPlatform(
    appId,
    socketAppId,
    normalizedPlatform,
  );

  message = await composeUserMessage({
    message,
    agentId: currentAgentId,
    resolvedAppId,
    normalizedPlatform,
    detailEntries: normalizeDetailEntries(details),
  });

  const agentProfile = new AgentInfo({
    id: currentAgentId,
    name: effectiveAvatarName,
    persona: effectivePersona,
    platform: normalizedPlatform,
    appId: resolvedAppId,
  });

  const onProgress = createProgressFanout({
    requestId,
    agentId: currentAgentId,
    appId: resolvedAppId,
    originUuid,
    isInterAgent,
    toAppId,
  });

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

