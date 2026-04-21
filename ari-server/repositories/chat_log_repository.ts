import path from "path";
import fs from "fs";
import { DATA_DIR, appendTextSync, unlinkSyncSafe } from "../infra/data.js";

const LOGS_DIR = path.join(DATA_DIR, "chat_logs");
const DEFAULT_SEGMENT = "default";

function resolveLogFile(appId: string | undefined, agentId: string | undefined): string {
  const a = appId && appId.length > 0 ? appId : DEFAULT_SEGMENT;
  const b = agentId && agentId.length > 0 ? agentId : DEFAULT_SEGMENT;
  return path.join(LOGS_DIR, `${a}__${b}.jsonl`);
}

/**
 * 로그 항목을 JSONL 파일에 추가합니다.
 */
export function appendChatLog(appId: string | undefined, agentId: string | undefined, entry: any): void {
  const filePath = resolveLogFile(appId, agentId);
  const logEntry = {
    ...entry,
    appId: appId ?? null,
    agentId: agentId ?? null,
    timestamp: entry.timestamp || new Date().toISOString(),
  };
  const line = JSON.stringify(logEntry) + "\n";
  appendTextSync(filePath, line);
}

/**
 * 로그를 최신순으로 페이지네이션하여 조회합니다.
 */
export function readChatLogs(
  appId: string | undefined,
  agentId: string | undefined,
  index: number,
  size: number,
): { logs: any[]; total: number } {
  const filePath = resolveLogFile(appId, agentId);
  if (!fs.existsSync(filePath)) {
    return { logs: [], total: 0 };
  }

  const content = fs.readFileSync(filePath, "utf-8");
  const lines = content.trim().split("\n").filter((l) => l.trim() !== "");
  const total = lines.length;

  const paginatedLines = lines.reverse().slice(index, index + size);

  const logs = paginatedLines
    .map((line) => {
      try {
        return JSON.parse(line);
      } catch {
        return null;
      }
    })
    .filter((l) => l !== null);

  return { logs, total };
}

/**
 * 특정 (appId, agentId) 쌍의 전체 로그 개수를 반환합니다.
 */
export function countChatLogs(appId: string | undefined, agentId: string | undefined): number {
  const filePath = resolveLogFile(appId, agentId);
  if (!fs.existsSync(filePath)) return 0;

  const content = fs.readFileSync(filePath, "utf-8");
  return content.trim().split("\n").filter((l) => l.trim() !== "").length;
}

/**
 * 최근 유저 메세지를 최신순으로 N개 반환합니다.
 */
export function readRecentUserMessages(
  appId: string | undefined,
  agentId: string | undefined,
  count: number,
): string[] {
  const filePath = resolveLogFile(appId, agentId);
  if (!fs.existsSync(filePath)) return [];

  const content = fs.readFileSync(filePath, "utf-8");
  const lines = content.trim().split("\n").filter((l) => l.trim() !== "");

  const userMessages: string[] = [];
  for (let i = lines.length - 1; i >= 0 && userMessages.length < count; i--) {
    try {
      const entry = JSON.parse(lines[i]);
      if (entry.type === "chat" && entry.isUser === true && entry.message) {
        userMessages.unshift(entry.message);
      }
    } catch {
      // skip
    }
  }
  return userMessages;
}

/**
 * 특정 (appId, agentId) 쌍의 로그 파일을 삭제합니다.
 */
export function clearChatLogs(appId: string | undefined, agentId: string | undefined): void {
  const filePath = resolveLogFile(appId, agentId);
  unlinkSyncSafe(filePath);
}
