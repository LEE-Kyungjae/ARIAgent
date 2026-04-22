import { AgentTool } from "@mariozechner/pi-agent-core";
import { Type } from "@mariozechner/pi-ai";
import fs from "fs";
import path from "path";
import { UserSocketHandler } from "../system/ws.js";
import { commandApp } from "../protocol/app.js";
import { logger } from "../infra/logger.js";
import { getBundleRoots } from "../infra/runtime_paths.js";
import { getExecutionContext } from "../services/agent/execution_context.js";
import { getAgentsConfig } from "../repositories/agent_repository.js";
import { AgentsConfig } from "../models/agent.js";

/**
 * read_app_state
 * 특정 앱의 현재 상태를 읽어오는 범용 도구
 */
export const readAppStateTool: AgentTool = {
  name: "read_app_state",
  label: "앱 상태 읽기",
  description:
    "특정 앱(ID 기반)의 현재 상태를 동기화하여 읽어옵니다. 사용자가 앱에서 수정한 내용을 확인할 때 사용합니다.",
  parameters: Type.Object({
    appId: Type.String({
      description: "읽어올 앱의 식별자 (예: notepad, youtube_player)",
    }),
  }),
  execute: async (_id, params) => {
    const { appId } = params as { appId: string };

    try {
      const result = await commandApp(appId, "GET_STATE");

      return {
        content: [
          {
            type: "text" as const,
            text: `✅ '${appId}' 앱의 실시간 상태:\n${JSON.stringify(result, null, 2)}`,
          },
        ],
        details: { state: result },
      };
    } catch (error: any) {
      logger.warn(`[read_app_state] Failed to query '${appId}': ${error.message}`);
      return {
        content: [
          {
            type: "text" as const,
            text: `❌ '${appId}' 앱과의 실시간 동기화에 실패했습니다: ${error.message}`,
          },
        ],
        details: { appId, success: false, error: error.message },
      };
    }
  },
};

/**
 * list_apps
 * 연결된 앱과 설치된 앱의 목록을 조회합니다.
 */
export const listAppsTool: AgentTool = {
  name: "list_apps",
  label: "앱 목록 조회",
  description:
    "현재 서버에 연결된 실시간 앱 ID 목록과 설치된 번들 앱 목록을 조회합니다. 명령을 내릴 앱의 식별자를 찾을 때 사용합니다.",
  parameters: Type.Object({}),
  execute: async () => {
    const connectedIds = UserSocketHandler.getConnectedAppIds();

    // 현재 에이전트의 pinnedAppIds 는 표시용 힌트로만 사용.
    // 모든 설치 앱은 에이전트와 무관하게 노출됨.
    const ctx = getExecutionContext();
    const pinnedSet: Set<string> = (() => {
      if (!ctx?.agentId) return new Set();
      const config = getAgentsConfig(new AgentsConfig());
      const agent = config.agents.find((a) => a.id === ctx.agentId);
      return agent ? new Set(agent.pinnedAppIds) : new Set();
    })();

    const bundleRoots = getBundleRoots();
    const installedApps: string[] = [];

    for (const root of bundleRoots) {
      if (fs.existsSync(root)) {
        const items = fs.readdirSync(root).filter((dir) => {
          const stats = fs.statSync(path.join(root, dir));
          if (!stats.isDirectory() || dir.startsWith(".") || dir === "__MACOSX") return false;
          return true;
        });
        installedApps.push(...items);
      }
    }

    const uniqueInstalled = Array.from(new Set(installedApps));
    const pinned = uniqueInstalled.filter((id) => pinnedSet.has(id));

    const renderItem = (id: string) =>
      pinnedSet.has(id) ? `- ${id} ⭐` : `- ${id}`;

    return {
      content: [
        {
          type: "text" as const,
          text:
            `📱 ARI 앱 목록:\n\n` +
            `🟢 연결됨 (Connected):\n${connectedIds.length > 0 ? connectedIds.map(renderItem).join("\n") : "(없음)"}\n\n` +
            `📦 설치됨 (Installed, ⭐ = pinned):\n${uniqueInstalled.length > 0 ? uniqueInstalled.map(renderItem).join("\n") : "(없음)"}`,
        },
      ],
      details: {
        connected: connectedIds,
        installed: uniqueInstalled,
        pinned,
      },
    };
  },
};

export const TOOLS = [listAppsTool, readAppStateTool];
