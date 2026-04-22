import { router } from "../system/router.js";
import { saveSettings } from "../repositories/setting_repository.js";
import { initAgent, getPluginsInfo, getCurrentState } from "../services/agent/index.js";
import { logger } from "../infra/logger.js";
import { getEmbeddingStatus, initEmbeddingModel } from "../services/embedding.js";
import { getAgentsConfig } from "../repositories/agent_repository.js";
import { AgentsConfig } from "../models/agent.js";

router.on("/SETTINGS", async (ctx, params) => {
  logger.info(`[Settings] Update requested by ${ctx.uuid}`);
  const state = getCurrentState();
  if (params.providers) {
    logger.info(`[Settings] Updating providers: ${params.providers.length} items`);
    const incoming = (params.providers as any[]).filter((p) => !!p.provider && !!p.model);
    const existing = state.providers || [];

    const nextProviders = incoming.map((inc) => {
      if (!inc.apiKey || inc.apiKey.includes("••")) {
        // accountId 우선 매칭, 없으면 provider로 fallback
        const matched =
          (inc.accountId && existing.find((ex: any) => ex.accountId === inc.accountId)) ??
          existing.find((ex: any) => ex.provider === inc.provider);
        inc.apiKey = matched?.apiKey || "";
      }
      return inc;
    });

    state.setProviders(nextProviders);
    saveSettings({ PROVIDERS: state.providers as any });
    await initAgent(state);
    return ctx.send("/SETTINGS", { ok: true, data: { success: true, providers: state.providers } });
  }

  if (params.apiKey) {
    logger.info(`[Settings] Updating API Key`);
    state.currentApiKey = params.apiKey;
  }
  if (params.model) {
    logger.info(`[Settings] Changing model to: ${params.model}`);
    state.currentModel = params.model;
  }
  if (params.provider) {
    logger.info(`[Settings] Changing provider to: ${params.provider}`);
    state.currentProvider = params.provider;
  }

  if (params.port) {
    logger.info(`[Settings] Changing port to: ${params.port}`);
    saveSettings({ PORT: Number(params.port) });
  }

  if (typeof params.language === "string") {
    const lang = params.language.trim();
    if (lang) {
      logger.info(`[Settings] Changing LANGUAGE to: ${lang}`);
      saveSettings({ LANGUAGE: lang });
    }
  }

  if (params.showTaskMessages !== undefined) {
    logger.info(
      `[Settings] Changing SHOW_TASK_MESSAGES to: ${params.showTaskMessages}`,
    );
    saveSettings({ SHOW_TASK_MESSAGES: params.showTaskMessages === true });
  }

  if (params.advancedMemory !== undefined) {
    const enabled = params.advancedMemory === true;
    logger.info(`[Settings] Changing USE_ADVANCED_MEMORY to: ${enabled}`);
    saveSettings({ USE_ADVANCED_MEMORY: enabled });
    if (enabled) {
      const status = getEmbeddingStatus();
      if (status.status === "idle" || status.status === "error") {
        logger.info(`[Settings] Advanced memory enabled — starting embedding model download`);
        initEmbeddingModel().catch((e) =>
          logger.error(`[Embedding] Background init failed:`, e),
        );
      }
    }
  }

  if (params.apiKey || params.model || params.provider) {
    saveSettings({
      OPENAI_API_KEY: state.currentApiKey,
      OPENAI_MODEL: state.currentModel,
      PROVIDER: state.currentProvider,
    });
    await initAgent();
  }

  ctx.send("/SETTINGS", { ok: true, data: { success: true, model: state.currentModel, provider: state.currentProvider } });
});

router.on("/PLUGINS.SKILLS", async (ctx, _params) => {
  logger.info(`[Plugins] Skills requested from ${ctx.uuid}`);
  const { skills } = await getPluginsInfo();
  ctx.send("/PLUGINS.SKILLS", { ok: true, data: { skills } });
});

router.on("/PLUGINS.APPS", async (ctx, params) => {
  const agentId = params?.agentId as string | undefined;
  logger.info(`[Plugins] Apps requested from ${ctx.uuid} (agentId: ${agentId ?? "all"})`);
  const { apps } = await getPluginsInfo();

  // agentId가 전달된 경우, 해당 에이전트의 appIds 기준으로 필터링
  if (agentId) {
    const config = getAgentsConfig(new AgentsConfig());
    const agent = config.agents.find((a) => a.id === agentId);
    if (agent) {
      const filtered = agent.filterVisibleSkills(apps);
      return ctx.send("/PLUGINS.APPS", { ok: true, data: { apps: filtered } });
    }
  }

  ctx.send("/PLUGINS.APPS", { ok: true, data: { apps } });
});

router.on("/PLUGINS.TOOLS", async (ctx, _params) => {
  logger.info(`[Plugins] Tools requested from ${ctx.uuid}`);
  const { tools } = await getPluginsInfo();
  ctx.send("/PLUGINS.TOOLS", {
    ok: true,
    data: { tools: tools.map((t) => ({ name: t.name, description: t.description })) },
  });
});
