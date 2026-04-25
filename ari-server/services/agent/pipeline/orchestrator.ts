import { getAgentsConfig } from "../../../repositories/agent_repository.js";
import { AgentInfo, AgentsConfig } from "../../../models/agent.js";
import {
  ChatWithAgentResult,
  PendingAgentResponse,
} from "../../../models/agent_response.js";
import { logger } from "../../../infra/logger.js";
import { buildSystemPrompt, pruneContext } from "./context_builder.js";
import { extractFinalResponseText } from "./response_parser.js";
import { runWithExecutionContext } from "../execution_context.js";
import { getOrCreateSession } from "../session/session_manager.js";
import { loadAllSkills } from "../../../skills/index.js";
import { loadMainTools } from "../../../tools/index.js";
import { isRequestCancellationError } from "./inter_agent.js";
import { agentState } from "../provider/state.js";
import {
  getCurrentSkills,
  getCurrentTools,
  setCurrentSkills,
  setCurrentTools,
} from "../plugin_cache.js";
import {
  broadcastEchoResponse,
  buildEchoMessage,
  isEchoMode,
} from "./echo_mode.js";
import {
  applyFollowUp,
  clearStaleRequests,
  decideQueueAction,
} from "./request_queue.js";
import { cancelAllInFlight, dropPendingResponse } from "../control.js";
import { forwardToAgent } from "../../../protocol/agent.js";
import { UserSocketHandler } from "../../../system/ws.js";
import { appendChatLog } from "../../../repositories/chat_log_repository.js";

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

async function chatWithAgent(
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

  // 룸 컨텍스트 = ari-broadcast (PM 방 팬아웃) 또는 PM 자신이 유저와 직접 대화 중.
  // 1:1 도메인(예: 유저→SARI 직접)은 룸 아님 — skip_turn 가이드를 걸어야 혼란스럽지 않다.
  const dispatchMode = pendingResponse?.dispatchMode;
  const isRoomContext =
    dispatchMode === "ari-broadcast" ||
    (dispatchMode === "user" && currentAgentProfile.appId === "ari");
  const systemPrompt = await buildSystemPrompt(
    session.agentInfo,
    agentState,
    isRoomContext,
    !!pendingResponse?.scheduledTask,
  );
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

  // R1: 팔로업 큐잉 대신, 진행 중 추론이 있으면 즉시 취소 후 새 요청 실행.
  // ari-broadcast 팬아웃이 진행 중이면 parentRequestId 로 sub-agent 세션도 cascade 취소.
  if (decideQueueAction(session) === "follow_up") {
    const prevParentRequestId = session.currentPendingResponse?.requestId;
    logger.info(
      `[Agent] Cancelling in-flight for ${agentId} (user re-entered, parent=${prevParentRequestId})`,
    );
    cancelAllInFlight(agentId, prevParentRequestId);
    // cancelAllInFlight 가 큐를 비우므로 현재 요청을 재등록.
    session.enqueueRequest(pendingResponse);
  }

  clearStaleRequests(session, pendingResponse.requestId, agentId);
  session.beginNextRequest();

  // user 메시지를 진입 시점에 chat log 에 기록.
  // - 응답 완료 시점에 적으면 ari-broadcast 응답이 PM 보다 빨리 도착 시 순서가 뒤바뀜.
  // - ari-broadcast: PM 측에서 이미 자기 진입 시 append — SARI 진입 때는 skip.
  if (
    pendingResponse.dispatchMode !== "ari-broadcast" &&
    pendingResponse.originUuid
  ) {
    appendChatLog(pendingResponse.appId, pendingResponse.agentId, {
      type: "chat",
      isUser: true,
      message: pendingResponse.originalMessage,
      requestId: pendingResponse.requestId,
      ...(pendingResponse.isInterAgent
        ? {
            from: pendingResponse.fromAppId,
            to: pendingResponse.appId,
            senderName: pendingResponse.senderName,
          }
        : {}),
    });
  }

  // PM 실행과 병렬로 연결된 타 앱 (SARI 등) 에 포워딩.
  // - isInterAgent 재발행 요청은 이미 포워딩된 결과 → 다시 팬아웃 X (무한 루프 방지).
  // - 스케줄러 발 (originUuid 없음) 은 R5 — PM 입구로만, 도메인엔 fanout X.
  if (
    !pendingResponse.isInterAgent &&
    pendingResponse.appId === "ari" &&
    pendingResponse.originUuid
  ) {
    for (const appId of UserSocketHandler.getConnectedAppIds()) {
      if (appId === "ari") continue;
      forwardToAgent(appId, {
        from: "ari",
        to: appId,
        message: pendingResponse.originalMessage,
        requestId: `${pendingResponse.requestId}-${appId}`,
        ttl: pendingResponse.ttl,
      });
    }
  }

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
