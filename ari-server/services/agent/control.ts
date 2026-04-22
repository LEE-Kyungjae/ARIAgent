/**
 * 세션 제어 (수명/취소/권한).
 * - abortAgent / clearAgentInstance: 실행 중 추론 중단, 세션 인스턴스 폐기
 * - dropPendingResponse: 응답 큐에서 특정 requestId 제거
 * - abortAgentsForOrigin: 소켓 종료 시 해당 소켓이 발행한 진행 요청 일괄 중단
 * - canCancelAgent: 취소 요청자의 소유권 확인 (originUuid 일치 또는 ari 앱)
 */

import { logger } from "../../infra/logger.js";
import { sendAgentCancel } from "../../protocol/agent.js";
import { appendChatLog } from "../../repositories/chat_log_repository.js";
import { getSettings } from "../../repositories/setting_repository.js";
import { Settings } from "../../models/settings.js";
import {
  clearAgentSession,
  getSession,
  listAgentSessions,
} from "./session/session_manager.js";

export function dropPendingResponse(agentId: string, requestId: string): void {
  const session = getSession(agentId);
  if (!session) {
    return;
  }

  session.removeRequest(requestId);
}

export function clearAgentInstance(agentId: string): void {
  clearAgentSession(agentId);
  logger.info(`[Agent] Instance cleared for: ${agentId}`);
}

export function abortAgent(agentId: string): void {
  const session = getSession(agentId);
  if (!session || !session.agent) {
    logger.warn(`[Agent] No active session to abort for: ${agentId}`);
    return;
  }

  // reset 전에 pending 캡처 — 취소 이벤트 발행 + 히스토리 persist 용.
  const pending = session.currentPendingResponse;
  const originUuid = pending?.originUuid;
  const requestId = pending?.requestId;

  // 취소돼도 유저 메시지는 히스토리에 남겨야 다음 턴에서 기억됨.
  // completeCurrentRequest 와 동일한 gating (originUuid 또는 SHOW_TASK_MESSAGES).
  if (pending) {
    const shouldPersist =
      !!pending.originUuid ||
      getSettings(new Settings()).SHOW_TASK_MESSAGES === true;
    if (shouldPersist) {
      appendChatLog(pending.appId, pending.agentId, {
        type: "chat",
        isUser: true,
        message: pending.originalMessage,
        requestId: pending.requestId,
      });
    }
  }

  session.agent.clearAllQueues();
  session.resetRequestQueue();
  session.agent.abort();
  logger.info(`[Agent] Thinking aborted for: ${agentId}`);

  // 모든 abort 경로 일원화: origin 에 /AGENT.CANCEL 이벤트 발행.
  if (originUuid) {
    sendAgentCancel({ uuid: originUuid }, { agentId, requestId });
  }
}

/**
 * 소켓 종료 시 해당 소켓이 발행한 진행 중 요청을 abort.
 * originUuid 가 일치하는 세션을 찾아 abortAgent 로 위임 —
 * 유저 메시지 persist / /AGENT.CANCEL 방출 / 큐 정리를 일원화.
 * 반환값은 abort 된 agentId 목록 (로깅용).
 */
export function abortAgentsForOrigin(originUuid: string): string[] {
  const aborted: string[] = [];
  for (const { agentId, session } of listAgentSessions()) {
    const pending = session.currentPendingResponse;
    if (pending?.originUuid !== originUuid) continue;
    abortAgent(agentId);
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
