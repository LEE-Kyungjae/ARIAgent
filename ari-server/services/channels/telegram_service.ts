import axios from "axios";
import { randomUUID } from "crypto";
import { logger } from "../../infra/logger.js";
import { getTelegramConfig } from "../../repositories/channel_repository.js";
import { getAgentsConfig } from "../../repositories/agent_repository.js";
import { AgentsConfig } from "../../models/agent.js";
import { ExecuteAgentRequestParams } from "../../models/agent_request.js";
import { executeAgentRequest } from "../agent/index.js";
import { appendChatLog } from "../../repositories/chat_log_repository.js";
import { sendAgentRequest } from "../../protocol/agent.js";

const TELEGRAM_API = "https://api.telegram.org/bot";

interface PollingState {
  active: boolean;
  lastUpdateId: number;
  consecutiveErrors: number;
  restartTimer?: NodeJS.Timeout;
}

const pollingStates = new Map<string, PollingState>();

function getOrCreateState(agentId: string): PollingState {
  let state = pollingStates.get(agentId);
  if (!state) {
    state = { active: false, lastUpdateId: 0, consecutiveErrors: 0 };
    pollingStates.set(agentId, state);
  }
  return state;
}

// ─────────────────────────────────────────────
// Telegram API helpers
// ─────────────────────────────────────────────

async function telegramGet(token: string, method: string, params: Record<string, any> = {}): Promise<any> {
  const url = `${TELEGRAM_API}${token}/${method}`;
  const res = await axios.get(url, { params, timeout: 35000 });
  return res.data;
}

async function telegramPost(token: string, method: string, data: Record<string, any>): Promise<any> {
  const url = `${TELEGRAM_API}${token}/${method}`;
  const res = await axios.post(url, data, { timeout: 10000 });
  return res.data;
}

export async function sendTelegramMessage(token: string, chatId: number, text: string): Promise<void> {
  try {
    await telegramPost(token, "sendMessage", {
      chat_id: chatId,
      text,
      parse_mode: "Markdown",
    });
  } catch {
    // Markdown 파싱 실패 시 plain text로 재시도
    try {
      await telegramPost(token, "sendMessage", { chat_id: chatId, text });
    } catch (err: any) {
      logger.error(`[Telegram] sendMessage 실패 (chatId=${chatId}): ${err.message}`);
    }
  }
}

export async function testTelegramConnection(token: string): Promise<{ ok: boolean; botName?: string; message?: string }> {
  try {
    const res = await telegramGet(token, "getMe");
    if (res.ok) {
      return { ok: true, botName: res.result.username };
    }
    return { ok: false, message: res.description || "Unknown error" };
  } catch (err: any) {
    return { ok: false, message: err.message };
  }
}

// ─────────────────────────────────────────────
// Long-polling loop
// ─────────────────────────────────────────────

// 연속 오류 횟수에 따른 대기 시간 (ms): 1s → 2s → 5s → 10s → 30s → 60s (최대)
const BACKOFF_MS = [1000, 2000, 5000, 10000, 30000, 60000];

async function pollOnce(agentId: string, token: string): Promise<boolean> {
  const state = getOrCreateState(agentId);
  let updates: any[];
  try {
    const res = await telegramGet(token, "getUpdates", {
      offset: state.lastUpdateId + 1,
      timeout: 30,
      allowed_updates: ["message"],
    });
    state.consecutiveErrors = 0;
    if (!res.ok || !Array.isArray(res.result)) return true;
    updates = res.result;
  } catch (err: any) {
    state.consecutiveErrors++;
    if (!err.message?.includes("ECONNRESET") && !err.code?.includes("ECONNABORTED")) {
      logger.warn(`[Telegram:${agentId}] getUpdates 오류: ${err.message}`);
    }
    return false;
  }

  for (const update of updates) {
    state.lastUpdateId = Math.max(state.lastUpdateId, update.update_id);

    const msg = update.message;
    if (!msg || !msg.text) continue;

    const chatId: number = msg.chat.id;
    const text: string = msg.text;
    const fromName: string = msg.from?.first_name || msg.from?.username || "Unknown";

    logger.info(`[Telegram:${agentId}] 메세지 수신 from ${fromName} (chatId=${chatId}): ${text}`);

    // LLM 응답 대기 중 polling 이 막히지 않도록 fire-and-forget.
    void handleIncomingMessage(token, agentId, chatId, text, fromName);
  }
  return true;
}

async function handleIncomingMessage(
  token: string,
  agentId: string,
  chatId: number,
  text: string,
  fromName: string,
): Promise<void> {
  const agentsConfig = getAgentsConfig(new AgentsConfig());
  const profile = agentsConfig.agents.find((a) => a.id === agentId);
  const requestId = randomUUID();

  // 텔레그램 발 사용자 입력을 ARI 채팅창에 노출 + 영구 기록.
  // executeAgentRequest 본류는 originUuid 가 없는 socket-less 호출에는
  // /AGENT.REQUEST 에코·user 메시지 chat_log append 를 건너뛴다.
  appendChatLog("ari", agentId, {
    type: "chat",
    isUser: true,
    message: text,
    requestId,
    channel: "telegram",
    from: fromName,
  });
  sendAgentRequest(
    { appId: "ari" },
    {
      message: text,
      requestId,
      agentId,
      appId: "ari",
      senderName: fromName,
    },
  );

  try {
    const result = await executeAgentRequest(
      new ExecuteAgentRequestParams({
        message: text,
        requestId,
        agentId,
        appId: "ari",
        platform: "telegram",
        avatarName: profile?.name,
        persona: profile?.persona,
        details: { chatId: String(chatId), from: fromName },
        waitForCompletion: true,
      }),
    );
    const reply = result.responseText?.trim();
    if (reply) {
      await sendTelegramMessage(token, chatId, reply);
    }
  } catch (err: any) {
    logger.error(`[Telegram:${agentId}] 에이전트 응답 실패 (chatId=${chatId}): ${err.message}`);
    await sendTelegramMessage(token, chatId, "⚠️ 에이전트 응답을 가져오지 못했습니다.");
  }
}

async function pollingLoop(agentId: string): Promise<void> {
  const state = getOrCreateState(agentId);
  while (state.active) {
    const config = getTelegramConfig(agentId);
    if (!config.enabled || !config.botToken) {
      state.active = false;
      break;
    }
    const ok = await pollOnce(agentId, config.botToken);
    if (!ok && state.active) {
      // 연속 오류 시 지수 백오프: 최대 60초 대기
      const delayMs = BACKOFF_MS[Math.min(state.consecutiveErrors - 1, BACKOFF_MS.length - 1)];
      await new Promise((resolve) => setTimeout(resolve, delayMs));
    }
  }
  logger.info(`[Telegram:${agentId}] Polling 종료`);
}

// ─────────────────────────────────────────────
// Public lifecycle API
// ─────────────────────────────────────────────

export function startTelegramPolling(agentId: string): void {
  const config = getTelegramConfig(agentId);
  if (!config.enabled || !config.botToken) {
    logger.info(`[Telegram:${agentId}] 비활성화 상태 — polling 시작 안 함`);
    return;
  }
  const state = getOrCreateState(agentId);
  if (state.active) {
    logger.info(`[Telegram:${agentId}] 이미 polling 중`);
    return;
  }

  state.active = true;
  state.lastUpdateId = 0;
  state.consecutiveErrors = 0;
  logger.info(`[Telegram:${agentId}] Polling 시작`);
  void pollingLoop(agentId);
}

export function stopTelegramPolling(agentId: string): void {
  const state = pollingStates.get(agentId);
  if (!state || !state.active) return;
  state.active = false;
  if (state.restartTimer) {
    clearTimeout(state.restartTimer);
    state.restartTimer = undefined;
  }
  logger.info(`[Telegram:${agentId}] Polling 중지 요청`);
}

export function restartTelegramPolling(agentId: string): void {
  stopTelegramPolling(agentId);
  const state = getOrCreateState(agentId);
  // 현재 진행 중인 getUpdates 요청이 끝날 때까지 잠깐 대기 후 재시작
  state.restartTimer = setTimeout(() => {
    state.restartTimer = undefined;
    startTelegramPolling(agentId);
  }, 1000);
}

export function isTelegramPollingActive(agentId: string): boolean {
  return pollingStates.get(agentId)?.active ?? false;
}
