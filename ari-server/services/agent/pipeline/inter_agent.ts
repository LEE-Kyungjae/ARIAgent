import { AgentsConfig } from "../../../models/agent.js";
import { getAgentsConfig } from "../../../repositories/agent_repository.js";

// ──────────────────────────────────────────────────────────────────────────────
// 요청 방향 해석 + TTL
// ──────────────────────────────────────────────────────────────────────────────

// 에이전트 간 전달 체인 기본 TTL. `/AGENT` 에 ttl 미지정 시 적용.
export const DEFAULT_INTER_AGENT_TTL = 5;

/**
 * `/AGENT` 라우팅 메타 해석.
 * - `to`: 대상 에이전트 appId (생략 시 sender 자기 자신).
 * - `from`: 발신 appId (생략 시 socketAppId).
 */
export function resolveInterAgentTarget(
  params: { from?: string; to?: string },
  socketAppId?: string,
): { targetAgentId: string; fromAppId?: string; toAppId?: string } {
  const fromAppId = params.from?.trim() || socketAppId || undefined;
  const explicitTo = params.to?.trim();
  const toAppId = explicitTo || fromAppId;

  const targetAgentId =
    getAgentsConfig(new AgentsConfig()).selected || "default";

  return { targetAgentId, fromAppId, toAppId };
}

export function isRequestCancellationError(error: unknown): boolean {
  if (!(error instanceof Error)) {
    return false;
  }

  const message = error.message.toLowerCase();
  return (
    message.includes("request aborted") ||
    message.includes("request queue reset")
  );
}

// ──────────────────────────────────────────────────────────────────────────────
// Forward 응답 대기 레지스트리
// ──────────────────────────────────────────────────────────────────────────────
// ARI 가 SARI 등 다른 앱 에이전트에게 자연어 지시(message)를 포워드하면,
// 대상 앱이 자기 쪽에서 세션을 돌려 /APP.PUSH 로 결과를 돌려준다. 그 시점까지
// 호출자 쪽 툴 실행은 여기 등록된 Promise 에 매달려 기다린다.
// - control_app 툴: registerForwardWaiter 로 대기자 등록
// - agent_session: 세션 완료/실패 시 resolve/reject 호출

interface ForwardWaiter {
  resolve: (text: string) => void;
  reject: (error: Error) => void;
  timer: NodeJS.Timeout;
}

const pendingForwards = new Map<string, ForwardWaiter>();

export function registerForwardWaiter(
  requestId: string,
  opts: { timeoutMs: number; timeoutMessage: string },
): Promise<string> {
  return new Promise<string>((resolve, reject) => {
    const timer = setTimeout(() => {
      if (pendingForwards.delete(requestId)) {
        reject(new Error(opts.timeoutMessage));
      }
    }, opts.timeoutMs);
    pendingForwards.set(requestId, { resolve, reject, timer });
  });
}

export function resolveForwardIfPending(
  requestId: string,
  responseText: string,
): boolean {
  const w = pendingForwards.get(requestId);
  if (!w) return false;
  pendingForwards.delete(requestId);
  clearTimeout(w.timer);
  w.resolve(responseText);
  return true;
}

export function rejectForwardIfPending(
  requestId: string,
  error: Error,
): boolean {
  const w = pendingForwards.get(requestId);
  if (!w) return false;
  pendingForwards.delete(requestId);
  clearTimeout(w.timer);
  w.reject(error);
  return true;
}
