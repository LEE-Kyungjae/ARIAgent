import { router } from "../system/router.js";
import { clearAgentMemory, readCoreMemory, readRecentDailyLogs, updateCoreMemory } from "../services/memory/index.js";
import { clearAgentInstance } from "../services/agent/index.js";

router.on("/MEMORY.GET", async (ctx, params) => {
  const agentId = (params.agentId as string) || "default";
  const core = readCoreMemory(agentId);
  const daily = readRecentDailyLogs(agentId);
  ctx.send("/MEMORY.GET", { ok: true, data: { core, daily } });
});

router.on("/MEMORY.UPDATE", async (ctx, params) => {
  const agentId = (params.agentId as string) || "default";
  const content = params.content as string;
  updateCoreMemory(content, agentId);
  ctx.send("/MEMORY.UPDATE", { ok: true, data: { success: true } });
});

router.on("/MEMORY.CLEAR", async (ctx, params) => {
  const agentId = (params.agentId as string) || "default";
  clearAgentMemory(agentId);
  clearAgentInstance(agentId);
  ctx.send("/MEMORY.CLEAR", { ok: true, data: { success: true } });
});
