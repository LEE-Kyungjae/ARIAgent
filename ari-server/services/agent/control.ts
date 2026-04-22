import { logger } from "../../infra/logger.js";
import {
  clearAgentSession,
  getSession,
  listAgentSessions,
} from "./session_manager.js";

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
