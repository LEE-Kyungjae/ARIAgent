import { logger } from "../../infra/logger.js";
import {
  AIProviderConfig,
  AIProviders,
  AvailablePlugins,
  Settings,
} from "../../models/settings.js";
import { getSettings } from "../../repositories/setting_repository.js";
import { getOAuthStatus } from "../oauth/index.js";
import {
  clearSkillCache,
  loadAvailableApps,
  loadAvailableSkills,
  loadSkillsForPrompt,
} from "../tools/skill_registry.js";
import { clearToolCache, loadMainTools } from "../tools/tool_registry.js";
import { ARI_CLOUD_PROVIDER, isOAuthProvider } from "./provider_selector.js";
import { clearAllAgentSessions } from "./session_manager.js";

type ToolsList = Awaited<ReturnType<typeof loadMainTools>>;
type SkillsList = Awaited<ReturnType<typeof loadAvailableSkills>>;

export const agentState = new AIProviders();

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

export async function initAgent(providersConfig?: AIProviders): Promise<void> {
  const globalSettings = getSettings(new Settings()) || {};
  const state = agentState;

  clearToolCache();
  clearSkillCache();
  currentTools = await loadMainTools();
  currentSkills = await loadSkillsForPrompt();

  if (providersConfig && providersConfig.providers.length > 0) {
    state.setProviders(providersConfig.providers);
  } else if (globalSettings.PROVIDERS && globalSettings.PROVIDERS.length > 0) {
    state.setProviders(globalSettings.PROVIDERS);
  } else {
    const defaultProvider = globalSettings.PROVIDER || "openai-codex";
    state.setProviders([
      new AIProviderConfig({
        provider: defaultProvider,
        model: globalSettings.OPENAI_MODEL || "gpt-5.3-codex",
        apiKey: globalSettings.OPENAI_API_KEY || "",
        authType: defaultProvider === "openai-codex" ? "oauth" : "apikey",
      }),
    ]);
  }
  const active =
    state.providers.find((provider) => !!provider.apiKey) || state.providers[0];
  state.currentModel =
    active?.model || globalSettings.OPENAI_MODEL || "gpt-5.3-codex";
  state.currentProvider =
    active?.provider || globalSettings.PROVIDER || "openai-codex";

  state.setAvailableProviders(
    (state.providers || []).filter((provider: AIProviderConfig) => {
      if (provider.apiKey) return true;
      if (provider.authType === "oauth" || isOAuthProvider(provider.provider)) {
        const oauthStatus = getOAuthStatus(provider.accountId);
        if (!oauthStatus.loggedIn) {
          logger.warn(
            `[Agent] OAuth provider ${provider.provider} (${provider.accountId}) is not logged in. Skipping.`,
          );
          return false;
        }
        return true;
      }
      return false;
    }),
  );
  clearAllAgentSessions();

  if (state.availableProviders.length === 0) {
    // 사용 가능한 프로바이더가 없으면 ARICloud 프록시를 통한 setup agent 모드로 전환
    const cloudSetupProvider = new AIProviderConfig({
      provider: ARI_CLOUD_PROVIDER,
      model: "gpt-4.1-mini",
      apiKey: "ari-cloud",
      authType: "apikey",
    });
    state.setAvailableProviders([cloudSetupProvider]);
    state.currentProvider = ARI_CLOUD_PROVIDER;
    state.currentModel = "gpt-4.1-mini";
    logger.info(
      "🌐 Setup 모드 — ARICloud 프록시를 통해 앱 사용 가이드 에이전트가 활성화됩니다.",
    );
    return;
  }

  logger.info(
    `✅ Agent initialized. (${state.availableProviders.length} providers loaded, current: ${state.currentProvider}/${state.currentModel})`,
  );
}

export function getCurrentState() {
  return agentState;
}

export async function getPluginsInfo(): Promise<AvailablePlugins> {
  getSettings(new Settings());
  if (currentTools.length === 0) {
    currentTools = await loadMainTools();
  }
  const [skills, apps] = await Promise.all([
    loadAvailableSkills(),
    loadAvailableApps(),
  ]);
  return { tools: currentTools, skills, apps };
}
