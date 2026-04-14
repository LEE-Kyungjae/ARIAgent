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
 * 특정 에이전트의 appIds에 appId를 추가하고 저장합니다.
 * 이미 목록에 있으면 아무 작업도 하지 않습니다.
 */
export function addAppIdToAgent(agentId: string, appId: string): void {
  const config = getAgentsConfig(new AgentsConfig());
  const agent = config.agents.find((a) => a.id === agentId);
  if (!agent) {
    logger.warn(`[AgentRepo] addAppIdToAgent: agent '${agentId}' not found`);
    return;
  }
  if (agent.addAppId(appId)) {
    saveAgents(config);
    logger.info(`[AgentRepo] Added app '${appId}' to agent '${agentId}'`);
  }
}

/**
 * 특정 에이전트의 appIds에서 appId를 제거하고 저장합니다.
 */
export function removeAppIdFromAgent(agentId: string, appId: string): void {
  const config = getAgentsConfig(new AgentsConfig());
  const agent = config.agents.find((a) => a.id === agentId);
  if (!agent) {
    logger.warn(`[AgentRepo] removeAppIdFromAgent: agent '${agentId}' not found`);
    return;
  }
  if (agent.removeAppId(appId)) {
    saveAgents(config);
    logger.info(`[AgentRepo] Removed app '${appId}' from agent '${agentId}'`);
  }
}

/**
 * 지정한 agentId를 제외한 다른 에이전트 중 해당 appId를 사용하는 에이전트가 있는지 확인합니다.
 */
export function isAppUsedByOtherAgents(agentId: string, appId: string): boolean {
  const config = getAgentsConfig(new AgentsConfig());
  return config.agents.some((a) => a.id !== agentId && a.appIds.includes(appId));
}
