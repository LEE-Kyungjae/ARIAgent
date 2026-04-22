import {
  readCoreMemory as dataReadCoreMemory,
  writeCoreMemory as dataWriteCoreMemory,
} from "../../repositories/memory_repository.js";
import {
  insertMemoryNode,
  deleteCoreMemoryNodes,
} from "../../repositories/sqlite_memory_repository.js";
import { embedPassage } from "../../infra/embedding.js";
import { logger } from "../../infra/logger.js";
import { MemoryGraphMeta, isAdvancedMemoryReady, resolveAgentId } from "./index.js";

export function updateCoreMemory(
  newContent: string,
  agentId?: string,
  meta: MemoryGraphMeta = {},
): void {
  const activeId = resolveAgentId(agentId);
  dataWriteCoreMemory(activeId, newContent);

  if (isAdvancedMemoryReady()) {
    (async () => {
      try {
        await deleteCoreMemoryNodes(activeId);
        const chunks = chunkText(newContent, 500);
        for (const chunk of chunks) {
          if (!chunk.trim()) continue;
          const embedding = await embedPassage(chunk);
          await insertMemoryNode({
            agentId: activeId,
            content: chunk,
            memType: "core",
            embedding,
            topics: meta.topics,
            entities: meta.entities,
            importance: meta.importance ?? "normal",
          });
        }
      } catch (e) {
        logger.error(`[Memory] core memory sync failed:`, e);
      }
    })();
  }
}

export function readCoreMemory(agentId?: string): string {
  const activeId = resolveAgentId(agentId);
  return dataReadCoreMemory(activeId);
}

function chunkText(text: string, maxLen: number): string[] {
  const paragraphs = text.split(/\n{2,}/);
  const chunks: string[] = [];
  let current = "";

  for (const para of paragraphs) {
    if ((current + "\n\n" + para).length > maxLen && current) {
      chunks.push(current.trim());
      current = para;
    } else {
      current = current ? current + "\n\n" + para : para;
    }
  }
  if (current.trim()) chunks.push(current.trim());
  return chunks;
}
