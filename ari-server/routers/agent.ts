import { router } from "../system/router.js";
import {
  abortAgent,
  canCancelAgent,
  clearAgentInstance,
  dropPendingResponse,
  executeAgentRequest,
} from "../services/agent/index.js";
import { logger } from "../infra/logger.js";
import { getAgentsConfig } from "../repositories/agent_repository.js";
import { AgentsConfig } from "../models/agent.js";
import { ExecuteAgentRequestParams } from "../models/agent_request.js";

function resolveAgentId(agentId?: string): string {
  return agentId || getAgentsConfig(new AgentsConfig()).selected || "default";
}

// /AGENT
router.on("/AGENT", async (ctx, params) => {
  const requestId = (params.requestId as string | undefined) || "";
  const rawTtl = Number(params.ttl);
  const ttl = Number.isFinite(rawTtl) ? Math.floor(rawTtl) : undefined;
  let resolvedAgentId: string | undefined;

  try {
    const result = await executeAgentRequest(
      new ExecuteAgentRequestParams({
        message: params.message as string,
        requestId,
        persona: params.persona as string | undefined,
        avatarName: params.avatarName as string | undefined,
        platform: params.platform as string | undefined,
        agentId: params.agentId as string | undefined,
        appId: params.appId as string | undefined,
        socketAppId: ctx.appId,
        // 원본 소켓 uuid. 응답 라우팅 타겟.
        originUuid: ctx.uuid,
        // 에이전트 간 라우팅 raw 입력 (서비스 내부에서 해석).
        from: params.from as string | undefined,
        to: params.to as string | undefined,
        ttl,
        details:
          params.details && typeof params.details === "object" && !Array.isArray(params.details)
            ? (params.details as Record<string, unknown>)
            : undefined,
      }),
    );

    resolvedAgentId = result.agentId;

    if (result.status === "cancelled") {
      dropPendingResponse(result.agentId, requestId);
      logger.info(`[/AGENT] Request cancelled by user: ${requestId}`);
      ctx.send("/AGENT", { ok: true, data: { status: "cancelled", requestId } });
      return;
    }

    ctx.send("/AGENT", { ok: true, data: { status: result.status, requestId } });
  } catch (err: any) {
    if (resolvedAgentId) {
      dropPendingResponse(resolvedAgentId, requestId);
    }
    ctx.send("/AGENT", { ok: false, message: err.message });
  }
});

// /AGENT.INTER  (다른 에이전트로부터 forward 된 메시지를 자기 페르소나로 처리)
//   - `/AGENT` 의 user-facing 분기와 격리. 무한 fanout 가능성 자체가 사라진다.
//   - 페이로드 보장: from, to(=내 appId), message, requestId, persona/avatarName, ttl.
router.on("/AGENT.INTER", async (ctx, params) => {
  const requestId = (params.requestId as string | undefined) || "";
  const rawTtl = Number(params.ttl);
  const ttl = Number.isFinite(rawTtl) ? Math.floor(rawTtl) : undefined;
  const to = (params.to as string | undefined) || ctx.appId;
  let resolvedAgentId: string | undefined;

  try {
    const result = await executeAgentRequest(
      new ExecuteAgentRequestParams({
        message: params.message as string,
        requestId,
        persona: params.persona as string | undefined,
        avatarName: params.avatarName as string | undefined,
        platform: "inter-agent",
        // 자기 에이전트로 처리. agentId 강제 = appId.
        agentId: to,
        appId: to,
        socketAppId: ctx.appId,
        originUuid: ctx.uuid,
        from: params.from as string | undefined,
        to,
        ttl,
      }),
    );

    resolvedAgentId = result.agentId;

    if (result.status === "cancelled") {
      dropPendingResponse(result.agentId, requestId);
      logger.info(`[/AGENT.INTER] Request cancelled by user: ${requestId}`);
      ctx.send("/AGENT.INTER", { ok: true, data: { status: "cancelled", requestId } });
      return;
    }

    ctx.send("/AGENT.INTER", { ok: true, data: { status: result.status, requestId } });
  } catch (err: any) {
    if (resolvedAgentId) {
      dropPendingResponse(resolvedAgentId, requestId);
    }
    ctx.send("/AGENT.INTER", { ok: false, message: err.message });
  }
});

// /AGENT.CANCEL  (소유권 검증 + 요청 소켓에만 응답)
router.on("/AGENT.CANCEL", async (ctx, params) => {
  const agentId = resolveAgentId(params.agentId as string | undefined);

  if (!canCancelAgent(agentId, ctx.uuid, ctx.appId)) {
    logger.warn(
      `[/AGENT.CANCEL] Rejected: uuid=${ctx.uuid} appId=${ctx.appId} is not owner of agent=${agentId}`,
    );
    ctx.send("/AGENT.CANCEL", {
      ok: false,
      message: "Not owner of agent session.",
    });
    return;
  }

  abortAgent(agentId);
  ctx.send("/AGENT.CANCEL", { ok: true, data: { agentId } });
});

// /AGENT.RESET
router.on("/AGENT.RESET", async (ctx, params) => {
  const agentId = resolveAgentId(params.agentId as string | undefined);

  clearAgentInstance(agentId);
  ctx.send("/AGENT.RESET", { ok: true, data: { agentId } });
});
