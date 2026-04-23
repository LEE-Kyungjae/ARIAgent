import { router } from "../system/router.js";
import { getTelegramConfig, saveTelegramConfig } from "../repositories/channel_repository.js";
import {
  testTelegramConnection,
  stopTelegramPolling,
  restartTelegramPolling,
  isTelegramPollingActive,
} from "../services/channels/telegram_service.js";

function resolveAgentId(params: Record<string, any>): string {
  const id = typeof params.agentId === "string" ? params.agentId.trim() : "";
  if (!id) throw new Error("agentId required");
  return id;
}

/**
 * /CHANNEL.GET {type: "telegram", agentId}
 * 채널 설정을 조회합니다.
 */
router.on("/CHANNEL.GET", async (ctx, params) => {
  const { type } = params;

  if (type === "telegram") {
    const agentId = resolveAgentId(params);
    const config = getTelegramConfig(agentId);
    // botToken은 마스킹하여 반환
    const masked = config.botToken
      ? config.botToken.replace(/:.+/, ":***")
      : "";
    ctx.send("/CHANNEL.GET", {
      ok: true,
      data: {
        ...config,
        botToken: masked,
        isPolling: isTelegramPollingActive(agentId),
      },
    });
    return;
  }

  ctx.send("/CHANNEL.GET", { ok: false, message: `Unknown channel type: ${type}` });
});

/**
 * /CHANNEL.SAVE {type: "telegram", agentId, botToken}
 * 채널 설정을 저장하고 polling을 재시작합니다.
 */
router.on("/CHANNEL.SAVE", async (ctx, params) => {
  const { type } = params;

  if (type === "telegram") {
    const agentId = resolveAgentId(params);
    const existing = getTelegramConfig(agentId);

    const botToken =
      typeof params.botToken === "string" && params.botToken && !params.botToken.includes("***")
        ? params.botToken.trim()
        : existing.botToken;

    const updated: ReturnType<typeof getTelegramConfig> = {
      ...existing,
      botToken,
      agentId,
    };

    saveTelegramConfig(updated);

    if (updated.enabled) {
      restartTelegramPolling(agentId);
    }

    ctx.send("/CHANNEL.SAVE", { ok: true, data: { type: "telegram", agentId } });
    return;
  }

  ctx.send("/CHANNEL.SAVE", { ok: false, message: `Unknown channel type: ${type}` });
});

/**
 * /CHANNEL.TOGGLE {type: "telegram", agentId, enabled: boolean}
 * 채널을 활성화/비활성화합니다.
 */
router.on("/CHANNEL.TOGGLE", async (ctx, params) => {
  const { type, enabled } = params;

  if (type === "telegram") {
    const agentId = resolveAgentId(params);
    const config = getTelegramConfig(agentId);

    if (!config.botToken) {
      ctx.send("/CHANNEL.TOGGLE", {
        ok: false,
        message: "Bot Token을 먼저 설정해 주세요.",
      });
      return;
    }

    config.enabled = !!enabled;
    saveTelegramConfig(config);

    if (config.enabled) {
      restartTelegramPolling(agentId);
    } else {
      stopTelegramPolling(agentId);
    }

    ctx.send("/CHANNEL.TOGGLE", {
      ok: true,
      data: {
        type: "telegram",
        agentId,
        enabled: config.enabled,
        isPolling: isTelegramPollingActive(agentId),
      },
    });
    return;
  }

  ctx.send("/CHANNEL.TOGGLE", { ok: false, message: `Unknown channel type: ${type}` });
});

/**
 * /CHANNEL.TEST {type: "telegram", botToken?, agentId?}
 * 봇 토큰이 유효한지 확인합니다. botToken 미지정 시 agentId 의 저장본 사용.
 */
router.on("/CHANNEL.TEST", async (ctx, params) => {
  const { type } = params;

  if (type === "telegram") {
    let token =
      typeof params.botToken === "string" && !params.botToken.includes("***")
        ? params.botToken.trim()
        : "";

    if (!token) {
      const agentId = resolveAgentId(params);
      token = getTelegramConfig(agentId).botToken;
    }

    if (!token) {
      ctx.send("/CHANNEL.TEST", { ok: false, message: "Bot Token이 없습니다." });
      return;
    }

    const result = await testTelegramConnection(token);
    ctx.send("/CHANNEL.TEST", {
      ok: result.ok,
      data: result.ok ? { botName: result.botName } : undefined,
      message: result.ok ? undefined : result.message,
    });
    return;
  }

  ctx.send("/CHANNEL.TEST", { ok: false, message: `Unknown channel type: ${type}` });
});
