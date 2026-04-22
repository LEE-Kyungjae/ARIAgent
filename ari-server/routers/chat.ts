import { router } from "../system/router.js";
import {
  readChatLogs,
  clearChatLogs,
} from "../repositories/chat_log_repository.js";

/**
 * /CHAT.GET_HISTORY {agentId, index, size}
 * 특정 에이전트의 대화 이력을 조회합니다.
 */
router.on("/CHAT.GET_HISTORY", async (ctx, params) => {
  const { appId, agentId, index = 0, size = 20 } = params;

  if (!agentId) {
    return ctx.send("/CHAT.GET_HISTORY", {
      ok: false,
      message: "agentId required",
    });
  }

  try {
    const { logs, total } = readChatLogs(
      appId as string | undefined,
      agentId as string,
      Number(index),
      Number(size),
    );
    ctx.send("/CHAT.GET_HISTORY", { ok: true, data: { logs, total } });
  } catch (err: any) {
    ctx.send("/CHAT.GET_HISTORY", { ok: false, message: err.message });
  }
});

/**
 * /CHAT.CLEAR {appId, agentId}
 * 특정 (appId, agentId) 쌍의 대화 이력을 삭제합니다.
 */
router.on("/CHAT.CLEAR", async (ctx, params) => {
  const { appId, agentId } = params;

  if (!agentId) {
    return ctx.send("/CHAT.CLEAR", { ok: false, message: "agentId required" });
  }

  try {
    clearChatLogs(appId as string | undefined, agentId as string);
    ctx.send("/CHAT.CLEAR", { ok: true, data: { appId, agentId } });
  } catch (err: any) {
    ctx.send("/CHAT.CLEAR", { ok: false, message: err.message });
  }
});
