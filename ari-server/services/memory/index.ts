import {
  hasWorkspace,
  removeCoreMemory,
  removeDailyMemoryDir,
} from "../../repositories/memory_repository.js";
import { logger } from "../../infra/logger.js";
import { getExecutionContext } from "../agent/execution_context.js";

export function resolveAgentId(agentId?: string): string {
  return agentId || getExecutionContext()?.agentId || "default";
}

export function clearAgentMemory(agentId?: string): void {
  const activeId = resolveAgentId(agentId);
  if (!hasWorkspace(activeId)) return;

  removeCoreMemory(activeId);
  removeDailyMemoryDir(activeId);

  logger.info(`[Memory] Cleared memory for agent: ${activeId}`);
}

export { updateCoreMemory, readCoreMemory } from "./core.js";
export {
  appendDailyMemory,
  readRecentDailyLogs,
  searchDailyLogs,
} from "./daily.js";
