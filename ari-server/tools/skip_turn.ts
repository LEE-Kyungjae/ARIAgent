import { AgentTool } from "@mariozechner/pi-agent-core";
import { Type } from "@mariozechner/pi-ai";
import { logger } from "../infra/logger.js";
import { getExecutionContext } from "../services/agent/execution_context.js";
import { getSession } from "../services/agent/session/session_manager.js";

/**
 * 이번 턴에 응답을 만들지 않고 종료한다.
 *
 * 사용 케이스:
 * - 그룹채팅(ARI 방) 에서 자기 도메인이 아닐 때
 * - 도메인 1:1 채팅에서 잡담·노이즈 입력일 때
 * - inter-agent forward 받았는데 처리할 일이 없을 때
 * - 스케줄러 발 작업인데 보고할 게 없을 때
 *
 * 호출 시 서버는 chat log append, push, thinking 시스템 메시지 모두 억제한다.
 * 클라 채팅창엔 아무 흔적도 남지 않는다.
 */
export const skipTurnTool: AgentTool = {
  name: "skip_turn",
  label: "응답 생략",
  description:
    "이번 턴에 응답하지 않고 침묵으로 넘긴다. 자기 차례가 아니거나 응답이 불필요할 때만 사용. " +
    "호출 후엔 어떤 텍스트도 출력하지 말 것.",
  parameters: Type.Object({
    reason: Type.Optional(
      Type.String({ description: "디버깅용 짧은 사유 (선택). 사용자에겐 노출 안 됨." }),
    ),
  }),
  execute: async (_id, params) => {
    const reason = (params as { reason?: string }).reason;
    const ctx = getExecutionContext();
    if (!ctx?.agentId) {
      logger.warn("[skip_turn] No execution context — ignored");
      return {
        content: [{ type: "text" as const, text: "skip ignored: no context" }],
        details: { skipped: false },
      };
    }
    const session = getSession(ctx.agentId);
    if (!session) {
      logger.warn(`[skip_turn] No session for ${ctx.agentId}`);
      return {
        content: [{ type: "text" as const, text: "skip ignored: no session" }],
        details: { skipped: false },
      };
    }
    session.markSkipped();
    session.agent.abort();
    logger.info(
      `[skip_turn] ${ctx.agentId}${reason ? ` — ${reason}` : ""}`,
    );
    return {
      content: [{ type: "text" as const, text: "이 턴은 응답 없이 종료합니다." }],
      details: { skipped: true, reason },
    };
  },
};

export const TOOLS = [skipTurnTool];
