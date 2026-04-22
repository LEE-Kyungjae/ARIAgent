import { AvailablePlugins, Settings } from "../../models/settings.js";
import { getSettings } from "../../repositories/setting_repository.js";
import { loadAllApps, loadAllSkills } from "../../skills/index.js";
import { loadMainTools } from "../../tools/index.js";

type ToolsList = Awaited<ReturnType<typeof loadMainTools>>;
type SkillsList = Awaited<ReturnType<typeof loadAllSkills>>;

/**
 * 프로세스 기동 후 한 번 로드되는 도구/스킬 캐시.
 * 세션 생성 시 매번 다시 스캔하지 않도록 메모리에 보관한다.
 * `initAgent` 가 초기 적재, `getPluginsInfo` 가 필요 시 lazy 재로드한다.
 */
let currentTools: ToolsList = [];
let currentSkills: SkillsList = [];

export function getCurrentTools(): ToolsList {
  return currentTools;
}

export function setCurrentTools(tools: ToolsList): void {
  currentTools = tools;
}

export function getCurrentSkills(): SkillsList {
  return currentSkills;
}

export function setCurrentSkills(skills: SkillsList): void {
  currentSkills = skills;
}

export async function getPluginsInfo(): Promise<AvailablePlugins> {
  // 설정 파일 사이드이펙트: Settings 싱글톤 초기화를 유도한다.
  getSettings(new Settings());
  if (currentTools.length === 0) {
    currentTools = await loadMainTools();
  }
  const [skills, apps] = await Promise.all([loadAllSkills(), loadAllApps()]);
  return { tools: currentTools, skills, apps };
}
