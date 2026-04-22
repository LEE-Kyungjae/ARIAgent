import {
  hasWorkspace,
  removeCoreMemory,
  removeDailyMemoryDir,
} from "../../repositories/memory_repository.js";
import {
  deleteAllMemoryNodes,
  searchMemoryNodes,
  EntityInput,
  Importance,
} from "../../repositories/sqlite_memory_repository.js";
import { embedQuery, getEmbeddingStatus } from "../../infra/embedding.js";
import { getSettings } from "../../repositories/setting_repository.js";
import { Settings } from "../../models/settings.js";
import { logger } from "../../infra/logger.js";
import { getExecutionContext } from "../agent/execution_context.js";

export interface MemoryGraphMeta {
  topics?: string[];
  entities?: EntityInput[];
  importance?: Importance;
}

export function isAdvancedMemoryReady(): boolean {
  const settings = getSettings(new Settings());
  if (!settings.USE_ADVANCED_MEMORY) return false;
  return getEmbeddingStatus().status === "ready";
}

export function resolveAgentId(agentId?: string): string {
  return agentId || getExecutionContext()?.agentId || "default";
}

export function clearAgentMemory(agentId?: string): void {
  const activeId = resolveAgentId(agentId);
  if (!hasWorkspace(activeId)) return;

  removeCoreMemory(activeId);
  removeDailyMemoryDir(activeId);

  deleteAllMemoryNodes(activeId).catch((e) =>
    logger.error(`[Memory] clear failed:`, e),
  );

  logger.info(`[Memory] Cleared memory for agent: ${activeId}`);
}

export async function searchRelevantMemories(
  query: string,
  agentId?: string,
  topK: number = 5,
): Promise<string> {
  const activeId = resolveAgentId(agentId);
  try {
    const queryEmbedding = await embedQuery(query);
    const results = await searchMemoryNodes(activeId, queryEmbedding, topK);
    if (results.length === 0) return "";

    return results
      .filter((r) => r.score > 0.3)
      .map((r) => {
        const tags: string[] = [];
        if (r.topics.length > 0) tags.push(`주제: ${r.topics.join(", ")}`);
        if (r.entities.length > 0) tags.push(`관련: ${r.entities.map((e) => e.name).join(", ")}`);
        const meta = tags.length > 0 ? ` (${tags.join(" | ")})` : "";
        return `[${r.memType}${meta}]\n${r.content}`;
      })
      .join("\n\n");
  } catch (e) {
    logger.error(`[Memory] 관련 메모리 검색 실패:`, e);
    return "";
  }
}

export { updateCoreMemory, readCoreMemory } from "./core.js";
export {
  appendDailyMemory,
  readRecentDailyLogs,
  searchDailyLogs,
} from "./daily.js";
