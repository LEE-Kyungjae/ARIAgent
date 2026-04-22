import path from "path";
import { DATA_DIR, fileExistsSync, readJsonSync, writeJsonSync } from "../infra/data.js";
import { AgentsConfig } from "../models/agent.js";
import { logger } from "../infra/logger.js";

const AGENTS_FILE = path.join(DATA_DIR, "agents.json");

export function getAgentsConfig(defaultConfig: AgentsConfig): AgentsConfig {
  if (!fileExistsSync(AGENTS_FILE)) {
    saveAgents(defaultConfig);
    return defaultConfig;
  }
  try {
    const configData = readJsonSync<any>(AGENTS_FILE, null);
    if (!configData) return defaultConfig;
    return AgentsConfig.fromJson(configData);
  } catch (e) {
    logger.error(`에이전트 설정 파싱 오류:`, e);
    return defaultConfig;
  }
}

export function saveAgents(agents: AgentsConfig | any): void {
  writeJsonSync(AGENTS_FILE, agents);
}

/**
 * 특정 에이전트의 pinnedAppIds에 appId를 추가하고 저장합니다.
 * 이미 핀되어 있으면 아무 작업도 하지 않습니다.
 */
export function pinAppToAgent(agentId: string, appId: string): boolean {
  const config = getAgentsConfig(new AgentsConfig());
  const agent = config.agents.find((a) => a.id === agentId);
  if (!agent) {
    logger.warn(`[AgentRepo] pinAppToAgent: agent '${agentId}' not found`);
    return false;
  }
  if (agent.pinApp(appId)) {
    saveAgents(config);
    logger.info(`[AgentRepo] Pinned app '${appId}' to agent '${agentId}'`);
    return true;
  }
  return false;
}

/**
 * 특정 에이전트의 pinnedAppIds에서 appId를 제거하고 저장합니다.
 */
export function unpinAppFromAgent(agentId: string, appId: string): boolean {
  const config = getAgentsConfig(new AgentsConfig());
  const agent = config.agents.find((a) => a.id === agentId);
  if (!agent) {
    logger.warn(`[AgentRepo] unpinAppFromAgent: agent '${agentId}' not found`);
    return false;
  }
  if (agent.unpinApp(appId)) {
    saveAgents(config);
    logger.info(`[AgentRepo] Unpinned app '${appId}' from agent '${agentId}'`);
    return true;
  }
  return false;
}

/**
 * 모든 에이전트의 pinnedAppIds에서 주어진 appId 를 일괄 제거합니다.
 * 앱 삭제 시 에이전트 핀 목록을 청소하기 위해 사용.
 */
export function sweepPinnedAppFromAllAgents(appId: string): number {
  const config = getAgentsConfig(new AgentsConfig());
  let changed = 0;
  for (const agent of config.agents) {
    if (agent.unpinApp(appId)) changed++;
  }
  if (changed > 0) {
    saveAgents(config);
    logger.info(
      `[AgentRepo] Swept app '${appId}' from ${changed} agent(s) pinned list`,
    );
  }
  return changed;
}
