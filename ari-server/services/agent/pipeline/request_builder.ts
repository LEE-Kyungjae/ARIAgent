import { Prompt } from "../../../infra/prompt.js";
import { readRecentUserMessages } from "../../../repositories/chat_log_repository.js";
import { UserSocketHandler } from "../../../system/ws.js";
import { loadAllApps } from "../../../skills/index.js";
import { readRecentDailyLogs } from "../../memory/index.js";

/**
 * `details` 가 객체라면 null 제외 후 `{key, value}` 페어 배열로 정규화.
 * 비객체/null 이면 빈 배열.
 */
export function normalizeDetailEntries(
  details?: Record<string, unknown>,
): Array<{ key: string; value: string }> {
  if (!details || typeof details !== "object" || Array.isArray(details)) {
    return [];
  }
  return Object.entries(details)
    .filter(([, value]) => value != null)
    .map(([key, value]) => ({
      key,
      value: typeof value === "string" ? value : JSON.stringify(value),
    }));
}

/**
 * 명시 appId 가 없을 때 platform 이름이 등록 앱과 일치하면 그것으로 폴백.
 */
export async function resolveAppIdFromPlatform(
  explicitAppId: string | undefined,
  socketAppId: string | undefined,
  normalizedPlatform: string,
): Promise<string | undefined> {
  const initial =
    (typeof explicitAppId === "string" ? explicitAppId.trim() : "") ||
    socketAppId ||
    undefined;
  if (initial || !normalizedPlatform) return initial;

  const apps = await loadAllApps();
  return apps.some((entry) => entry.name === normalizedPlatform)
    ? normalizedPlatform
    : undefined;
}

/**
 * 사용자 메시지에 앱/시각/최근 로그 등 컨텍스트를 입혀 LLM 입력 메시지를 만든다.
 * (loadedSkills 는 message history 의 read_skill tool_result 가 보존되므로 별도 inject 안 함.)
 */
export async function composeUserMessage(opts: {
  message: string;
  agentId: string;
  avatarName: string;
  resolvedAppId?: string;
  normalizedPlatform: string;
  detailEntries: Array<{ key: string; value: string }>;
  /** ARI 방 그룹챗 컨텍스트면 room participants 노출. 1:1 모드에선 숨김. */
  showRoomParticipants?: boolean;
}): Promise<string> {
  const connectedAppIds = UserSocketHandler.getConnectedAppIds();
  const recentDailyLogs = readRecentDailyLogs(opts.agentId);
  const recentUserMessages = readRecentUserMessages(
    opts.resolvedAppId,
    opts.agentId,
    5,
  );

  return Prompt.load("app_user_context.hbs", {
    now_str: new Date().toISOString(),
    avatarName: opts.avatarName,
    appId: opts.resolvedAppId,
    platform: opts.normalizedPlatform,
    details: opts.detailEntries,
    connectedAppIds:
      opts.showRoomParticipants && connectedAppIds.length > 0
        ? connectedAppIds
        : undefined,
    recentDailyLogs: recentDailyLogs || undefined,
    recentUserMessages:
      recentUserMessages.length > 0 ? recentUserMessages : undefined,
    message: opts.message,
  });
}
