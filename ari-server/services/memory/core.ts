import {
  readCoreMemory as dataReadCoreMemory,
  writeCoreMemory as dataWriteCoreMemory,
} from "../../repositories/memory_repository.js";
import { resolveAgentId } from "./index.js";

export function updateCoreMemory(newContent: string, agentId?: string): void {
  const activeId = resolveAgentId(agentId);
  dataWriteCoreMemory(activeId, newContent);
}

export function readCoreMemory(agentId?: string): string {
  const activeId = resolveAgentId(agentId);
  return dataReadCoreMemory(activeId);
}
