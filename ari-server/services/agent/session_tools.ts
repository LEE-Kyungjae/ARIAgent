import { AgentTool } from "@mariozechner/pi-agent-core";
import { MAIN_TOOL_NAMES, loadAllTools } from "../../tools/index.js";

let cachedAllTools: AgentTool[] = [];
let cachedMainTools: AgentTool[] = [];

function buildMergedTools(
  mainTools: AgentTool[],
  allTools: AgentTool[],
  extraToolNames: Iterable<string>,
): AgentTool[] {
  const merged = new Map<string, AgentTool>();

  for (const tool of mainTools) {
    merged.set(tool.name, tool);
  }

  for (const toolName of extraToolNames) {
    const tool = allTools.find((entry) => entry.name === toolName);
    if (tool) {
      merged.set(tool.name, tool);
    }
  }

  return [...merged.values()];
}

export async function buildSessionTools(
  extraToolNames: Iterable<string>,
): Promise<AgentTool[]> {
  const allTools = await loadAllTools();
  cachedAllTools = allTools;
  cachedMainTools = allTools.filter((tool) => MAIN_TOOL_NAMES.has(tool.name));
  return buildMergedTools(cachedMainTools, cachedAllTools, extraToolNames);
}

export function buildSessionToolsSync(
  extraToolNames: Iterable<string>,
): AgentTool[] {
  // 런타임 중(inference phase)에는 buildSessionTools(async)가 먼저 호출돼 캐시가 채워져 있어야 합니다.
  return buildMergedTools(cachedMainTools, cachedAllTools, extraToolNames);
}
