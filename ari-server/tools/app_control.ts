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

const LAUNCH_WAIT_TIMEOUT_MS = 15_000;
const LAUNCH_POLL_INTERVAL_MS = 300;
const SHUTDOWN_COMMAND = "SHUTDOWN";

function resolveAppExecutable(appName: string): string {
  const executable = findAppExecutable(appName);
  if (executable) return executable;
  throw new Error(`로컬 ${appName} 실행 파일을 찾지 못했습니다.`);
}

async function waitForAppConnection(
  appId: string,
  timeoutMs: number,
): Promise<boolean> {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (UserSocketHandler.isAppConnected(appId)) return true;
    await new Promise((r) => setTimeout(r, LAUNCH_POLL_INTERVAL_MS));
  }
  return UserSocketHandler.isAppConnected(appId);
}

function spawnApp(
  appName: string,
  env?: Record<string, string>,
  args?: string[],
) {
  const executable = resolveAppExecutable(appName);
  logger.info(
    `[ControlApp] Launching '${appName}' via: ${executable} (args: ${JSON.stringify(args || [])})`,
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
    logger.error(`[ControlApp] ${appName} 실행 실패: ${error.message}`);
  });
  child.on("spawn", () => {
    logger.info(
      `[ControlApp] ${appName} spawned (pid: ${child.pid ?? "unknown"}) log: ${launchLogPath}`,
    );
  });
  child.on("exit", (code, signal) => {
    logger.warn(
      `[ControlApp] ${appName} exited (code: ${code ?? "null"}, signal: ${signal ?? "null"})`,
    );
  });
  child.unref();
}

/**
 * control_app
 *
 * 단일 동작: 앱에 명령을 전송합니다.
 *  - 앱이 꺼져 있으면 자동으로 실행 후 연결을 기다려 명령을 전송합니다.
 *  - 종료도 별도 action이 아닌 'SHUTDOWN' 명령으로 처리합니다. (앱이 SHUTDOWN을 받으면 스스로 정리 후 종료)
 *  - command === 'SHUTDOWN'이고 앱이 이미 꺼져 있다면 no-op으로 반환합니다. (종료 의도로 앱을 켜지 않음)
 *
 * 프리즈/무응답 앱의 강제 종료는 이 도구가 담당하지 않습니다. 필요하면 execute_bash로 OS 레벨 처리하세요.
 */
export const controlAppTool: AgentTool = {
  name: "control_app",
  label: "앱 제어",
  description:
    "앱에 명령을 전송합니다. 앱이 꺼져 있으면 자동으로 실행 후 명령을 전달합니다. 앱을 끄고 싶을 때는 'SHUTDOWN' 명령을 보내세요 (앱이 스스로 종료).",
  parameters: Type.Object({
    app: Type.String({
      description: "대상 앱 식별자 (번들/폴더 이름이자 WebSocket appId)",
    }),
    command: Type.String({
      description:
        "전송할 명령어 (예: UPDATE, PLAY, PAUSE, SHUTDOWN). 'SHUTDOWN'은 앱에게 스스로 종료하라는 약속된 명령입니다.",
    }),
    params: Type.Optional(
      Type.Any({ description: "명령어에 필요한 파라미터 객체 (선택)" }),
    ),
    env: Type.Optional(
      Type.Record(Type.String(), Type.String(), {
        description: "자동 실행 시 앱에 전달할 환경변수 (선택)",
      }),
    ),
    args: Type.Optional(
      Type.Array(Type.String(), {
        description: "자동 실행 시 앱에 전달할 명령행 인자 (선택)",
      }),
    ),
  }),
  execute: async (_id, params) => {
    const {
      app,
      command,
      params: cmdParams,
      env,
      args,
    } = params as {
      app: string;
      command: string;
      params?: any;
      env?: Record<string, string>;
      args?: string[];
    };

    const isConnected = UserSocketHandler.isAppConnected(app);
    const isShutdown = command === SHUTDOWN_COMMAND;

    // 종료 명령인데 이미 꺼져 있으면 no-op — 종료하려고 앱을 켤 이유가 없음
    if (isShutdown && !isConnected) {
      return {
        content: [
          {
            type: "text" as const,
            text: `ℹ️ '${app}' 앱이 이미 실행되지 않은 상태입니다. SHUTDOWN을 건너뜁니다.`,
          },
        ],
        details: { app, command, success: true, skipped: true },
      };
    }

    // 필요 시 자동 실행 + 연결 대기
    if (!isConnected) {
      logger.info(`[ControlApp] '${app}' 미연결 상태 — 자동 실행 시도`);

      try {
        spawnApp(app, env, args);
      } catch (error: any) {
        return {
          content: [
            {
              type: "text" as const,
              text: `❌ '${app}' 앱 자동 실행 실패: ${error.message}`,
            },
          ],
          details: { app, command, success: false, error: error.message },
        };
      }

      const connected = await waitForAppConnection(app, LAUNCH_WAIT_TIMEOUT_MS);
      if (!connected) {
        return {
          content: [
            {
              type: "text" as const,
              text: `❌ '${app}' 앱이 ${LAUNCH_WAIT_TIMEOUT_MS / 1000}초 내에 서버에 연결되지 않았습니다.`,
            },
          ],
          details: { app, command, success: false, launched: true, connected: false },
        };
      }
      logger.info(`[ControlApp] '${app}' 연결 확인됨 — 명령 전송 진행`);
    }

    try {
      const result = await UserSocketHandler.commandApp(
        app,
        command,
        cmdParams || {},
      );

      const isAppError = result?.status === "error" || result?.ok === false;

      if (isAppError) {
        return {
          content: [
            {
              type: "text" as const,
              text: `❌ '${app}' 앱에서 명령 실행 중 에러가 발생했습니다:\n${result?.message || JSON.stringify(result)}`,
            },
          ],
          details: {
            app,
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
            text: `🚀 '${app}' 앱의 '${command}' 실행 결과:\n${JSON.stringify(result, null, 2)}`,
          },
        ],
        details: { app, command, params: cmdParams, result, success: true },
      };
    } catch (error: any) {
      return {
        content: [
          {
            type: "text" as const,
            text: `❌ '${app}' 앱으로 명령 전송 또는 실행 실패: ${error.message}`,
          },
        ],
        details: { app, command, success: false, error: error.message },
      };
    }
  },
};

export const TOOLS = [controlAppTool];
