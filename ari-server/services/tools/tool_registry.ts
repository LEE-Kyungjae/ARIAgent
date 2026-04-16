import { AgentTool } from "@mariozechner/pi-agent-core";
import { loadAllTools } from "../../tools/index.js";
import { APP_CONTROL_MODE } from "../../tools/app_control_mode.js";

// A/B: unified면 `control_app` 하나만, legacy면 기존 send/lifecycle 쌍을 메인툴로 노출.
const APP_CONTROL_MAIN_TOOLS =
  APP_CONTROL_MODE === "unified"
    ? ["control_app"]
    : ["send_app_command", "app_lifecycle"];

const MAIN_TOOL_NAMES = new Set<string>([
  "execute_bash",
  "sleep",
  "update_core_memory",
  "append_daily_memory",
  "read_skill",
  "web_fetch",
  ...APP_CONTROL_MAIN_TOOLS,
]);

let cachedAllTools: AgentTool[] = [];
let cachedMainTools: AgentTool[] = [];

export async function loadMainTools(): Promise<AgentTool[]> {
  const allTools = await loadAllTools();
  cachedAllTools = allTools;
  cachedMainTools = allTools.filter((tool) => MAIN_TOOL_NAMES.has(tool.name));
  return cachedMainTools;
}

async function loadCachedTools(): Promise<AgentTool[]> {
  const allTools = await loadAllTools();
  cachedAllTools = allTools;
  return allTools;
}

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
  const allTools = await loadCachedTools();
  const mainTools = await loadMainTools();
  return buildMergedTools(mainTools, allTools, extraToolNames);
}

export function buildSessionToolsSync(
  extraToolNames: Iterable<string>,
): AgentTool[] {
  // 런타임 중(inference phase)에는 최신 상태가 캐시에 이미 로드되어 있어야 합니다.
  return buildMergedTools(cachedMainTools, cachedAllTools, extraToolNames);
}

export function clearToolCache(): void {
  // 캐시를 사용하지 않으므로 비워둡니다.
}
