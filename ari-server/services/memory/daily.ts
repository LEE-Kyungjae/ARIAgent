import {
  appendDailyMemoryLine,
  readDailyMemory,
  hasDailyMemory,
  listDailyMemoryFiles,
} from "../../repositories/memory_repository.js";
import { MemoryGraphMeta, resolveAgentId } from "./index.js";

function getTodayString(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

function getYesterdayString(): string {
  const d = new Date();
  d.setDate(d.getDate() - 1);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

function parseDailyEntries(dateStr: string, agentId: string): string[] {
  const log = readDailyMemory(agentId, `${dateStr}.md`);
  if (!log.trim()) return [];
  return log
    .split(/\n{2,}/)
    .map((e) => e.trim())
    .filter((e) => e && !e.startsWith("# Daily Log:"));
}

export function appendDailyMemory(
  content: string,
  agentId?: string,
  meta: MemoryGraphMeta = {},
): void {
  const activeId = resolveAgentId(agentId);
  const todayFilename = `${getTodayString()}.md`;

  const prefix = !hasDailyMemory(activeId, todayFilename)
    ? `# Daily Log: ${getTodayString()}\n\n`
    : "\n\n";

  appendDailyMemoryLine(activeId, todayFilename, prefix + content);
}

export function readRecentDailyLogs(agentId?: string, maxEntries = 10): string {
  const activeId = resolveAgentId(agentId);
  const yesterday = parseDailyEntries(getYesterdayString(), activeId);
  const today = parseDailyEntries(getTodayString(), activeId);

  const all = [...yesterday, ...today];
  const recent = all.slice(-maxEntries);
  return recent.join("\n\n");
}

export function searchDailyLogs(query: string, agentId?: string): string {
  const activeId = resolveAgentId(agentId);
  const lowerQuery = query.toLowerCase();
  const files = listDailyMemoryFiles(activeId);
  const matches: string[] = [];

  for (const filename of files) {
    const dateStr = filename.replace(".md", "");
    const entries = parseDailyEntries(dateStr, activeId);
    for (const entry of entries) {
      if (entry.toLowerCase().includes(lowerQuery)) {
        matches.push(`[${dateStr}] ${entry}`);
      }
    }
  }

  return matches.join("\n\n");
}
