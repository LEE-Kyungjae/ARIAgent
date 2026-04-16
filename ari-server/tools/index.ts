import path from "path";
import fs from "fs";
import { readDirSyncSafe, DATA_DIR, ensureDirSync } from "../infra/data.js";
import { AgentTool } from "@mariozechner/pi-agent-core";
import { logger } from "../infra/logger.js";
import { TOOLS as APP_CONTROL_TOOLS } from "./app_control.js";
import { TOOLS as CONTROL_APP_TOOLS } from "./control_app.js";
import { TOOLS as APP_STATUS_TOOLS } from "./app_status.js";
import { TOOLS as APP_INSTALL_TOOLS } from "./app_install.js";
import { TOOLS as BASH_TOOLS } from "./bash.js";
import { TOOLS as CREATE_SKILL_TOOLS } from "./create_skill.js";
import { TOOLS as CREDENTIAL_TOOLS } from "./credentials.js";
import { TOOLS as RELOAD_SKILLS_TOOLS } from "./reload_skills.js";
import { TOOLS as SCHEDULE_TOOLS } from "./schedule.js";
import { TOOLS as WEB_BROWSER_TOOLS } from "./web_browser.js";
import { TOOLS as WEB_FETCH_TOOLS } from "./web_fetch.js";
import { TOOLS as UTILS_TOOLS } from "./utils.js";
import { TOOLS as HA_TOOLS } from "./homeassistant.js";
import { updateCoreMemoryTool } from "./core_memory_tool.js";
import { appendDailyMemoryTool } from "./daily_memory_tool.js";
import { searchMemoryTool } from "./search_memory_tool.js";
import { readSkillTool } from "./read_skill.js";
import { APP_CONTROL_MODE } from "./app_control_mode.js";

// A/B 스위치: 레거시(app_control) vs 실험적 통합(control_app).
// 두 arm은 상호 배타적으로 로드되며 `list_apps`/`read_app_state`는 양쪽 모두에 공통 적용됩니다.
const APP_TOOLSET =
  APP_CONTROL_MODE === "unified" ? CONTROL_APP_TOOLS : APP_CONTROL_TOOLS;

const BUILT_IN_TOOLS = [
  ...APP_TOOLSET,
  ...APP_STATUS_TOOLS,
  ...APP_INSTALL_TOOLS,
  ...BASH_TOOLS,
  ...CREATE_SKILL_TOOLS,
  ...CREDENTIAL_TOOLS,
  ...RELOAD_SKILLS_TOOLS,
  ...SCHEDULE_TOOLS,
  ...WEB_BROWSER_TOOLS,
  ...WEB_FETCH_TOOLS,
  ...UTILS_TOOLS,
  ...HA_TOOLS,
  updateCoreMemoryTool,
  appendDailyMemoryTool,
  searchMemoryTool,
  readSkillTool,
] as AgentTool[];

async function loadToolsFromDir(dirPath: string): Promise<AgentTool[]> {
  const tools: AgentTool[] = [];
  if (!fs.existsSync(dirPath)) return tools;

  const files = readDirSyncSafe(dirPath);
  for (const file of files) {
    if (!file.endsWith(".ts") && !file.endsWith(".js") && !file.endsWith(".mjs") && !file.endsWith(".cjs")) {
      continue;
    }

    try {
      const modulePath = path.resolve(dirPath, file);
      const module = await import(modulePath);

      if (module.TOOLS && Array.isArray(module.TOOLS)) {
        tools.push(...module.TOOLS);
      } else {
        for (const key of Object.keys(module)) {
          const val = module[key];
          if (val && typeof val === "object" && typeof val.execute === "function" && typeof val.name === "string") {
            tools.push(val);
          }
        }
      }
    } catch (err) {
      logger.warn(`Failed to load tool from ${file} in ${dirPath}:`, err);
    }
  }
  return tools;
}

export async function loadAllTools(): Promise<AgentTool[]> {
  const toolMap = new Map<string, AgentTool>();

  for (const tool of BUILT_IN_TOOLS) {
    toolMap.set(tool.name, tool);
  }

  const userToolsDir = path.join(DATA_DIR, "tools");
  ensureDirSync(userToolsDir);
  const userTools = await loadToolsFromDir(userToolsDir);
  for (const tool of userTools) {
    toolMap.set(tool.name, tool);
  }

  return Array.from(toolMap.values());
}
