import { AgentMessage } from "@mariozechner/pi-agent-core";
import { logger } from "../../infra/logger.js";
import { PendingAgentResponse } from "../../models/agent_response.js";
import { sendAgentFollowUp } from "../../protocol/agent.js";
import { AgentSession } from "./agent_session.js";

/**
 * 큐 분기 결정.
 * - `follow_up`: 이미 추론 중 → 메시지를 follow-up 으로 큐잉.
 * - `execute`: 즉시 실행 가능.
 */
export type QueueAction = "follow_up" | "execute";

export function decideQueueAction(session: AgentSession): QueueAction {
  return session.agent.state.isStreaming ? "follow_up" : "execute";
}

/**
 * 추론 중인 세션에 follow-up 메시지를 추가하고 발신자에게 통지.
 */
export function applyFollowUp(
  session: AgentSession,
  message: string,
  agentId: string,
  pendingResponse: PendingAgentResponse,
): void {
  session.agent.followUp({
    role: "user",
    content: [{ type: "text", text: message }],
    timestamp: Date.now(),
  } as AgentMessage);
  sendAgentFollowUp(pendingResponse.originUuid, {
    ok: true,
    data: {
      requestId: pendingResponse.requestId,
      message: pendingResponse.originalMessage,
      agentId,
      reason: "busy",
    },
  });
  logger.info(
    `[Agent] Follow-up queued for ${agentId} (${pendingResponse.requestId})`,
  );
}

/**
 * 즉시 실행 직전에 잔존하는 다른 requestId 의 pending 을 정리.
 * 정상 흐름에선 비어있어야 하지만, 비정상 종료 등으로 누적될 수 있어 방어적으로 처리.
 */
export function clearStaleRequests(
  session: AgentSession,
  requestId: string,
  agentId: string,
): void {
  if (
    session.currentPendingResponse &&
    session.currentPendingResponse.requestId !== requestId
  ) {
    logger.warn(
      `[Agent] Clearing stale current pending request for ${agentId}: ${session.currentPendingResponse.requestId}`,
    );
    session.currentPendingResponse = null;
  }

  const stale = session.pendingResponses.filter(
    (item) => item.requestId !== requestId,
  );
  if (stale.length > 0) {
    logger.warn(
      `[Agent] Clearing ${stale.length} stale pending request(s) before immediate execution for ${agentId}.`,
    );
    session.pendingResponses = session.pendingResponses.filter(
      (item) => item.requestId === requestId,
    );
  }
}
