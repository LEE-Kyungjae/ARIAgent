import fs from "fs";
import path from "path";
import os from "os";
import { router } from "../system/router.js";
import { getAgentsConfig, saveAgents } from "../repositories/agent_repository.js";
import { AgentsConfig } from "../models/agent.js";

router.on("/AGENTS", async (ctx, params) => {
  const config = getAgentsConfig(new AgentsConfig());
  ctx.send("/AGENTS", { ok: true, data: config });
});

router.on("/AGENTS.SAVE", async (ctx, params) => {
  const payload = params.agents as any;
  if (!payload) return ctx.send("/AGENTS.SAVE", { ok: false, message: "agents data required" });

  const config = getAgentsConfig(new AgentsConfig());
  const newConfig = Array.isArray(payload) ? { selected: config.selected, agents: payload } : payload;

  saveAgents(newConfig);
  ctx.send("/AGENTS.SAVE", { ok: true, data: { success: true } });
});

router.on("/AGENTS.SET_SELECTED", async (ctx, params) => {
  const id = params.id as string;
  if (!id) return ctx.send("/AGENTS.SET_SELECTED", { ok: false, message: "id required" });

  const config = getAgentsConfig(new AgentsConfig());
  config.selected = id;
  saveAgents(config);
  ctx.send("/AGENTS.SET_SELECTED", { ok: true, data: { success: true } });
});

router.on("/AGENTS.IMAGE.SAVE", async (ctx, params) => {
  const id = params.id as string;
  const sourcePath = params.sourcePath as string;

  if (!id || !sourcePath) {
    return ctx.send("/AGENTS.IMAGE.SAVE", { ok: false, message: "id and sourcePath required" });
  }

  try {
    const imagesDir = path.join(os.homedir(), ".ari-agent", "images");
    if (!fs.existsSync(imagesDir)) {
      fs.mkdirSync(imagesDir, { recursive: true });
    }

    const ext = path.extname(sourcePath);
    const destPath = path.join(imagesDir, `${id}${ext}`);

    if (path.resolve(sourcePath) === path.resolve(destPath)) {
      return ctx.send("/AGENTS.IMAGE.SAVE", { ok: true, data: { imagePath: sourcePath } });
    }

    fs.copyFileSync(sourcePath, destPath);
    ctx.send("/AGENTS.IMAGE.SAVE", { ok: true, data: { imagePath: destPath } });
  } catch (e: any) {
    ctx.send("/AGENTS.IMAGE.SAVE", { ok: false, message: e.message });
  }
});
