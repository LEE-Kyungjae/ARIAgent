import axios from "axios";
import { logger } from "../../infra/logger.js";
import { getTelegramConfig } from "../../repositories/channel_repository.js";

const TELEGRAM_API = "https://api.telegram.org/bot";

// Telegram 어댑터는 현재 비활성 상태입니다.
// sender-push persona 모델 재정비 중이며, 재구현 전까지는 polling/웹훅을 기동하지 않습니다.
// 파일은 재구현 시 참고용으로 남겨둡니다.
const TELEGRAM_ADAPTER_DISABLED = true;

let pollingActive = false;
let pollingTimer: NodeJS.Timeout | undefined;
let lastUpdateId = 0;

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

async function pollOnce(token: string, agentId?: string): Promise<void> {
  let updates: any[];
  try {
    const res = await telegramGet(token, "getUpdates", {
      offset: lastUpdateId + 1,
      timeout: 30,
      allowed_updates: ["message"],
    });
    if (!res.ok || !Array.isArray(res.result)) return;
    updates = res.result;
  } catch (err: any) {
    if (!err.message?.includes("ECONNRESET") && !err.code?.includes("ECONNABORTED")) {
      logger.warn(`[Telegram] getUpdates 오류: ${err.message}`);
    }
    return;
  }

  for (const update of updates) {
    lastUpdateId = Math.max(lastUpdateId, update.update_id);

    const msg = update.message;
    if (!msg || !msg.text) continue;

    const chatId: number = msg.chat.id;
    const text: string = msg.text;
    const fromName: string = msg.from?.first_name || msg.from?.username || "Unknown";

    logger.info(`[Telegram] 메세지 수신 from ${fromName} (chatId=${chatId}): ${text}`);

    // 어댑터 비활성 상태 — 수신만 로깅하고 응답은 보내지 않음.
    void agentId;
    void fromName;
    void text;
  }
}

async function pollingLoop(): Promise<void> {
  while (pollingActive) {
    const config = getTelegramConfig();
    if (!config.enabled || !config.botToken) {
      // 설정이 비활성화되면 루프 종료
      pollingActive = false;
      break;
    }
    await pollOnce(config.botToken, config.agentId);
  }
  logger.info("[Telegram] Polling 종료");
}

// ─────────────────────────────────────────────
// Public lifecycle API
// ─────────────────────────────────────────────

export function startTelegramPolling(): void {
  if (TELEGRAM_ADAPTER_DISABLED) {
    logger.info("[Telegram] 어댑터 비활성 — polling skip");
    return;
  }
  const config = getTelegramConfig();
  if (!config.enabled || !config.botToken) {
    logger.info("[Telegram] 비활성화 상태 — polling 시작 안 함");
    return;
  }
  if (pollingActive) {
    logger.info("[Telegram] 이미 polling 중");
    return;
  }

  pollingActive = true;
  lastUpdateId = 0;
  logger.info("[Telegram] Polling 시작");
  void pollingLoop();
}

export function stopTelegramPolling(): void {
  if (!pollingActive) return;
  pollingActive = false;
  if (pollingTimer) {
    clearTimeout(pollingTimer);
    pollingTimer = undefined;
  }
  logger.info("[Telegram] Polling 중지 요청");
}

export function restartTelegramPolling(): void {
  stopTelegramPolling();
  // 현재 진행 중인 getUpdates 요청이 끝날 때까지 잠깐 대기 후 재시작
  pollingTimer = setTimeout(() => {
    pollingTimer = undefined;
    startTelegramPolling();
  }, 1000);
}

export function isTelegramPollingActive(): boolean {
  return pollingActive;
}
