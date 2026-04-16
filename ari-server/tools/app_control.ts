/**
 * [LEGACY] 앱 제어 도구 세트
 *
 * 이 파일은 `control_app.ts`(실험적 통합 도구)와의 A/B 테스트를 위한 **레거시 arm**입니다.
 * `read_app_state`, `list_apps`는 공통 도구이므로 `app_status.ts`로 이동되었습니다.
 *
 * A/B 테스트가 종료되어 `control_app`으로 완전 전환이 결정되면 이 파일 전체를 삭제하면 됩니다.
 */
import { AgentTool } from "@mariozechner/pi-agent-core";
import { Type } from "@mariozechner/pi-ai";
import { spawn } from "child_process";
import fs from "fs";
import os from "os";
import path from "path";
import { UserSocketHandler } from "../system/ws.js";
import { logger } from "../infra/logger.js";
import { findAppExecutable } from "../infra/runtime_paths.js";
import { DATA_DIR } from "../infra/data.js";

function resolveAppExecutable(appName: string): string {
  const executable = findAppExecutable(appName);
  if (executable) return executable;
  throw new Error(`로컬 ${appName} 실행 파일을 찾지 못했습니다.`);
}

export const sendAppCommandTool: AgentTool = {
  name: "send_app_command",
  label: "앱 명령 전송",
  description:
    "실행 중인 특정 앱에 제어 명령을 보냅니다. 해당 앱의 SKILL.md 파일에서 지원하는 명령어 목록을 먼저 확인하십시오.",
  parameters: Type.Object({
    appId: Type.String({
      description: "명령을 받을 앱의 식별자 (예: youtube_player, notepad)",
    }),
    command: Type.String({
      description: "실행할 명령어 (예: UPDATE, PLAY, PAUSE 등)",
    }),
    params: Type.Optional(
      Type.Any({ description: "명령어에 필요한 파라미터 객체" }),
    ),
  }),
  execute: async (_id, params) => {
    const {
      appId,
      command,
      params: cmdParams,
    } = params as { appId: string; command: string; params?: any };

    try {
      const result = await UserSocketHandler.commandApp(
        appId,
        command,
        cmdParams || {},
      );

      const isAppError = result?.status === "error" || result?.ok === false;

      if (isAppError) {
        return {
          content: [
            {
              type: "text" as const,
              text: `❌ '${appId}' 앱에서 명령 실행 중 에러가 발생했습니다:\n${result?.message || JSON.stringify(result)}`,
            },
          ],
          details: {
            appId,
            command,
            params: cmdParams,
            result,
            success: false,
            error: result?.message,
          },
        };
      }

      return {
        content: [
          {
            type: "text" as const,
            text: `🚀 '${appId}' 앱의 '${command}' 실행 결과:\n${JSON.stringify(result, null, 2)}`,
          },
        ],
        details: { appId, command, params: cmdParams, result, success: true },
      };
    } catch (error: any) {
      return {
        content: [
          {
            type: "text" as const,
            text: `❌ '${appId}' 앱으로 명령 전송 또는 실행 실패: ${error.message}`,
          },
        ],
        details: { appId, command, success: false, error: error.message },
      };
    }
  },
};

async function launchApp(
  appName: string,
  env?: Record<string, string>,
  args?: string[],
) {
  if (UserSocketHandler.isAppConnected(appName)) {
    return {
      content: [
        {
          type: "text" as const,
          text: `⚠️ '${appName}' 앱이 이미 실행 중이며 서버에 연결되어 있습니다. 새로운 작업을 수행하려면 'send_app_command'를 사용하세요.`,
        },
      ],
      details: { appName, success: false, alreadyRunning: true },
    };
  }

  const executable = resolveAppExecutable(appName);
  logger.info(
    `[AppLifecycle] Launching app '${appName}' via: ${executable} (args: ${JSON.stringify(args || [])})`,
  );

  const launchLogDir = path.join(DATA_DIR, "launch-logs");
  fs.mkdirSync(launchLogDir, { recursive: true });
  const launchLogPath = path.join(launchLogDir, `${appName}.log`);
  const stdoutFd = fs.openSync(launchLogPath, "a");
  const stderrFd = fs.openSync(launchLogPath, "a");

  const defaultArgs = args || [];

  const bundlePath =
    process.platform === "darwin"
      ? executable.split("/Contents/MacOS/")[0]
      : null;
  const launcherExecutable =
    process.platform === "darwin" ? "open" : executable;
  const launcherArgs =
    process.platform === "darwin" && bundlePath
      ? defaultArgs.length > 0
        ? ["-n", bundlePath, "--args", ...defaultArgs]
        : ["-n", bundlePath]
      : defaultArgs;

  const child = spawn(launcherExecutable, launcherArgs, {
    detached: process.platform === "darwin" ? false : true,
    stdio: ["ignore", stdoutFd, stderrFd],
    cwd: path.dirname(executable),
    env: {
      ...process.env,
      HOME: process.env.HOME ?? os.homedir(),
      USERPROFILE: process.env.USERPROFILE ?? os.homedir(),
      ...env,
    },
  });

  child.on("error", (error: any) => {
    logger.error(`[AppLifecycle] ${appName} 실행 실패: ${error.message}`);
  });
  child.on("spawn", () => {
    logger.info(
      `[AppLifecycle] ${appName} spawned (pid: ${child.pid ?? "unknown"}) log: ${launchLogPath}`,
    );
  });
  child.on("exit", (code, signal) => {
    logger.warn(
      `[AppLifecycle] ${appName} exited (code: ${code ?? "null"}, signal: ${signal ?? "null"})`,
    );
  });
  child.unref();

  return {
    content: [{ type: "text" as const, text: `✅ '${appName}' 앱을 실행했습니다.` }],
    details: { appName, success: true },
  };
}

async function terminateApp(appName: string) {
  logger.info(`[AppLifecycle] Terminating app: ${appName}`);

  await new Promise<void>((resolve) => {
    let child;
    if (process.platform === "darwin") {
      child = spawn("pkill", ["-x", appName], { stdio: "ignore" });
    } else if (process.platform === "win32") {
      child = spawn("taskkill", ["/IM", `${appName}.exe`, "/F"], {
        stdio: "ignore",
        windowsHide: true,
      });
    } else {
      resolve();
      return;
    }
    child.on("error", () => resolve());
    child.on("exit", () => resolve());
  });

  await new Promise((resolve) => setTimeout(resolve, 250));

  return {
    content: [{ type: "text" as const, text: `✅ '${appName}' 앱을 종료했습니다.` }],
    details: { appName, success: true },
  };
}

export const appLifecycleTool: AgentTool = {
  name: "app_lifecycle",
  label: "앱 실행/종료",
  description:
    "OS 레벨에서 앱 프로세스를 실행하거나 종료합니다. action으로 'launch' 또는 'terminate'를 지정합니다.",
  parameters: Type.Object({
    action: Type.String({
      description: "수행할 동작: 'launch' (실행) 또는 'terminate' (종료)",
    }),
    appName: Type.String({
      description: "대상 앱의 이름 (번들/폴더 이름)",
    }),
    env: Type.Optional(
      Type.Record(Type.String(), Type.String(), {
        description: "앱에 전달할 환경변수 (launch 시 선택)",
      }),
    ),
    args: Type.Optional(
      Type.Array(Type.String(), {
        description: "앱에 전달할 명령행 인자 (launch 시 선택)",
      }),
    ),
  }),
  execute: async (_id, params) => {
    const { action, appName, env, args } = params as {
      action: string;
      appName: string;
      env?: Record<string, string>;
      args?: string[];
    };

    if (action === "launch") {
      return launchApp(appName, env, args);
    }
    if (action === "terminate") {
      return terminateApp(appName);
    }
    return {
      content: [
        {
          type: "text" as const,
          text: `❌ 알 수 없는 action: '${action}'. 'launch' 또는 'terminate'를 사용하세요.`,
        },
      ],
      details: { appName, action, success: false },
    };
  },
};

export const TOOLS = [sendAppCommandTool, appLifecycleTool];
