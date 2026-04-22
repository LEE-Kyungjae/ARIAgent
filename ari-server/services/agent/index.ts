/**
 * services/agent — 에이전트 서브시스템 퍼사드.
 *
 * 외부(라우터/툴/시스템)가 에이전트와 상호작용하는 단일 진입점.
 * 내부 하위 폴더(session/pipeline/provider) 는 여기서만 조립해 노출하고,
 * 외부가 직접 import 하지 않는다.
 *
 * 같은 폴더의 형제 파일:
 * - bootstrap.ts         : 프로세스 기동 시 런타임 초기화 (`initAgent`).
 * - control.ts           : 세션 제어 (abort/clear/drop, origin-기반 권한 검증).
 * - execution_context.ts : AsyncLocalStorage 기반 도구 실행 컨텍스트
 *                          (현재 agentId/appId/ttl 을 도구 코드에서 읽게 해주는 레일).
 * - plugin_cache.ts      : 도구/스킬/앱 목록 프로세스 캐시.
 * - session/             : 대화 세션 상태·턴 루프·세션 전용 도구 빌드.
 * - pipeline/            : 요청 한 건의 가공·큐잉·실행 흐름
 *                          (request_builder → orchestrator → 응답 팬아웃).
 * - provider/            : AI 프로바이더 상태(state) 와 선택 로직(selector).
 */

import { AgentInfo } from "../../models/agent.js";
import {
  ExecuteAgentResult,
  PendingAgentResponse,
} from "../../models/agent_response.js";
import { ExecuteAgentRequestParams } from "../../models/agent_request.js";
import { logger } from "../../infra/logger.js";
import {
  DEFAULT_INTER_AGENT_TTL,
  resolveInterAgentTarget,
} from "./pipeline/inter_agent.js";
import { createProgressFanout } from "./pipeline/progress_fanout.js";
import {
  composeUserMessage,
  normalizeDetailEntries,
  resolveAppIdFromPlatform,
} from "./pipeline/request_builder.js";
import {
  submitAgentRequest,
  submitAgentRequestAndWait,
} from "./pipeline/orchestrator.js";

export { initAgent } from "./bootstrap.js";
export { getCurrentState } from "./provider/state.js";
export { getPluginsInfo } from "./plugin_cache.js";
export {
  abortAgent,
  abortAgentsForOrigin,
  canCancelAgent,
  clearAgentInstance,
  dropPendingResponse,
} from "./control.js";

export async function executeAgentRequest(
  params: ExecuteAgentRequestParams,
): Promise<ExecuteAgentResult> {
  const { requestId } = params;
  const originalMessage = params.message;

  const resolved = resolveInterAgentTarget(
    { from: params.from, to: params.to },
    params.socketAppId,
  );
  const currentAgentId = params.agentId || resolved.targetAgentId;

  // 루프 방지: TTL 소진 시 거부. 미지정 시 기본값 적용.
  const isInterAgent = !!(
    resolved.fromAppId &&
    resolved.toAppId &&
    resolved.fromAppId !== resolved.toAppId
  );
  const effectiveTtl =
    typeof params.ttl === "number" && Number.isFinite(params.ttl)
      ? params.ttl
      : DEFAULT_INTER_AGENT_TTL;
  if (isInterAgent && effectiveTtl <= 0) {
    logger.warn(
      `[Agent] Rejected inter-agent request: ttl=${effectiveTtl} (${resolved.fromAppId} → ${resolved.toAppId})`,
    );
    throw new Error(`Inter-agent TTL exhausted (${effectiveTtl})`);
  }

  if (!originalMessage) {
    throw new Error("message required");
  }

  const resolvedAppId = await resolveAppIdFromPlatform(
    params.appId,
    params.socketAppId,
    params.platform,
  );

  const message = await composeUserMessage({
    message: originalMessage,
    agentId: currentAgentId,
    resolvedAppId,
    normalizedPlatform: params.platform,
    detailEntries: normalizeDetailEntries(params.details),
  });

  const agentProfile = new AgentInfo({
    id: currentAgentId,
    name: params.avatarName,
    persona: params.persona,
    platform: params.platform,
    appId: resolvedAppId,
  });

  const onProgress = createProgressFanout({
    requestId,
    agentId: currentAgentId,
    appId: resolvedAppId,
    originUuid: params.originUuid,
    isInterAgent,
    toAppId: resolved.toAppId,
  });

  const pendingResponse: PendingAgentResponse = {
    requestId,
    agentId: currentAgentId,
    originalMessage,
    appId: resolvedAppId,
    // 원본 소켓. 없으면 task (스케줄러) 기원 — 응답은 drop.
    originUuid: params.originUuid,
    // 에이전트 간 라우팅 메타. 응답 채널 분기에 사용.
    fromAppId: resolved.fromAppId,
    toAppId: resolved.toAppId,
    isInterAgent,
    ttl: effectiveTtl,
  };

  if (params.waitForCompletion) {
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
