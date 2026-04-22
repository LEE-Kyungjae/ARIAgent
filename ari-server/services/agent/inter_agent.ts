import { AgentsConfig } from "../../models/agent.js";
import { getAgentsConfig } from "../../repositories/agent_repository.js";

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
