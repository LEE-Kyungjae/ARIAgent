import { AgentTool } from "@mariozechner/pi-agent-core";
import { Type } from "@mariozechner/pi-ai";
import fs from "fs";
import path from "path";
import { appStateService } from "../services/app_state_service.js";
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
      logger.warn(
        `[read_app_state] Failed to query '${appId}': ${error.message}. Falling back to cache.`,
      );

      const state = appStateService.getState(appId);
      if (!state) {
        return {
          content: [
            {
              type: "text" as const,
              text: `❌ '${appId}' 앱과의 실시간 동기화에 실패했으며 캐시된 정보도 없습니다: ${error.message}`,
            },
          ],
          details: { appId, success: false, error: error.message },
        };
      }

      return {
        content: [
          {
            type: "text" as const,
            text: `⚠️ '${appId}' 앱 실시간 조회 실패(캐시 데이터 반환):\n${JSON.stringify(state.state, null, 2)}`,
          },
        ],
        details: { state: state.state, cached: true },
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

    const ctx = getExecutionContext();
    const agentAppIds: Set<string> | null = (() => {
      if (!ctx?.agentId) return null;
      const config = getAgentsConfig(new AgentsConfig());
      const agent = config.agents.find((a) => a.id === ctx.agentId);
      return agent ? new Set(agent.appIds) : null;
    })();

    const bundleRoots = getBundleRoots();
    const installedApps: string[] = [];

    for (const root of bundleRoots) {
      if (fs.existsSync(root)) {
        const items = fs.readdirSync(root).filter((dir) => {
          const stats = fs.statSync(path.join(root, dir));
          if (!stats.isDirectory() || dir.startsWith(".") || dir === "__MACOSX") return false;
          return agentAppIds ? agentAppIds.has(dir) : true;
        });
        installedApps.push(...items);
      }
    }

    const uniqueInstalled = Array.from(new Set(installedApps));

    return {
      content: [
        {
          type: "text" as const,
          text:
            `📱 ARI 앱 목록:\n\n` +
            `🟢 연결됨 (Connected):\n${connectedIds.length > 0 ? connectedIds.map((id) => `- ${id}`).join("\n") : "(없음)"}\n\n` +
            `📦 설치됨 (Installed):\n${uniqueInstalled.length > 0 ? uniqueInstalled.map((id) => `- ${id}`).join("\n") : "(없음)"}`,
        },
      ],
      details: { connected: connectedIds, installed: uniqueInstalled },
    };
  },
};

export const TOOLS = [listAppsTool, readAppStateTool];
