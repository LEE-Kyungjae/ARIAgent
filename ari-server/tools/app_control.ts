import { AgentTool } from "@mariozechner/pi-agent-core";
import { Type } from "@mariozechner/pi-ai";
import { spawn } from "child_process";
import crypto from "crypto";
import fs from "fs";
import os from "os";
import path from "path";
import { UserSocketHandler } from "../system/ws.js";
import { commandApp } from "../protocol/app.js";
import { forwardToAgent } from "../protocol/agent.js";
import { logger } from "../infra/logger.js";
import { findAppExecutable } from "../infra/runtime_paths.js";
import { DATA_DIR } from "../infra/data.js";
import { getExecutionContext } from "../services/agent/execution_context.js";
import { registerForwardWaiter } from "../services/agent/forward_registry.js";

export const LAUNCH_WAIT_TIMEOUT_MS = 15_000;
const LAUNCH_POLL_INTERVAL_MS = 300;
const SHUTDOWN_COMMAND = "SHUTDOWN";
const FORWARD_WAIT_TIMEOUT_MS = 5 * 60 * 1000;

function resolveAppExecutable(appName: string): string {
  const executable = findAppExecutable(appName);
  if (executable) return executable;
  throw new Error(`로컬 ${appName} 실행 파일을 찾지 못했습니다.`);
}

export async function waitForAppConnection(
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

export function spawnApp(
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
 * control_app — 통합 앱 제어 툴
 *
 * 두 가지 호출 모드:
 *  1. **대화 위임 모드** (`message` 지정): 자연어 메시지를 대상 앱 에이전트에게 전달하고 응답을 받는다.
 *     - 대상 에이전트가 스스로 판단해서 자기 내부 프로토콜을 발동한다.
 *     - 호출자가 커맨드 이름·파라미터를 알 필요 없음.
 *  2. **커맨드 모드** (`command` 지정): 앱의 내부 프로토콜 커맨드를 직접 보낸다.
 *     - 라이프사이클(`SHUTDOWN`) 또는 자기 자신에게 도메인 커맨드를 발동할 때 사용.
 *     - 꺼져 있으면 자동 실행 후 연결 대기.
 *     - `SHUTDOWN` + 이미 꺼짐 = no-op.
 *
 * `message` 와 `command` 는 동시에 지정할 수 없다.
 */
export const controlAppTool: AgentTool = {
  name: "control_app",
  label: "앱 제어",
  description:
    "대상 앱을 제어합니다. `message` 로 자연어 지시를 보내면 대상 에이전트가 스스로 판단해 수행하고 응답합니다. `command` 로 내부 프로토콜 커맨드를 직접 보낼 수도 있습니다 (`SHUTDOWN` 으로 종료, 자기 자신 호출 등).",
  parameters: Type.Object({
    app: Type.String({
      description: "대상 앱 식별자 (번들/폴더 이름이자 WebSocket appId)",
    }),
    message: Type.Optional(
      Type.String({
        description:
          "자연어 지시 (위임). 대상 에이전트가 받아 스스로 판단해 수행합니다. `command` 와 함께 쓸 수 없습니다.",
      }),
    ),
    command: Type.Optional(
      Type.String({
        description:
          "내부 프로토콜 커맨드. 라이프사이클 종료는 'SHUTDOWN'. `message` 와 함께 쓸 수 없습니다.",
      }),
    ),
    params: Type.Optional(
      Type.Any({ description: "커맨드 모드에서 필요한 파라미터 객체 (선택)" }),
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
      message,
      command,
      params: cmdParams,
      env,
      args,
    } = params as {
      app: string;
      message?: string;
      command?: string;
      params?: any;
      env?: Record<string, string>;
      args?: string[];
    };

    if (!app) {
      return errorResult("❌ `app` 은 필수입니다.", { success: false });
    }

    const hasMessage = typeof message === "string" && message.trim().length > 0;
    const hasCommand = typeof command === "string" && command.trim().length > 0;

    if (hasMessage && hasCommand) {
      return errorResult(
        "❌ `message` 와 `command` 는 동시에 지정할 수 없습니다. 하나만 선택하세요.",
        { success: false, app },
      );
    }
    if (!hasMessage && !hasCommand) {
      return errorResult(
        "❌ `message` 또는 `command` 중 하나는 반드시 지정해야 합니다.",
        { success: false, app },
      );
    }

    if (hasMessage) {
      return runMessageMode(app, message!.trim());
    }

    return runCommandMode(app, command!, cmdParams, env, args);
  },
};

function errorResult(text: string, details: Record<string, unknown>) {
  return {
    content: [{ type: "text" as const, text }],
    details,
  };
}

async function runMessageMode(app: string, message: string) {
  const ctx = getExecutionContext();
  const fromAppId = ctx?.appId || ctx?.agentId || "ari";
  // 현재 호출의 잔여 TTL 에서 1 감소. 미설정(ctx 없음)이면 undefined → 수신 서버가 기본값 적용.
  const forwardedTtl =
    typeof ctx?.ttl === "number" ? ctx.ttl - 1 : undefined;

  if (app === fromAppId) {
    return errorResult(
      "❌ `message` 모드로 자기 자신에게 말을 걸 수 없습니다. 자기 도메인 작업은 `command` 모드를 쓰세요.",
      { success: false, app, fromAppId },
    );
  }

  if (!UserSocketHandler.isAppConnected(app)) {
    logger.info(`[ControlApp:message] '${app}' 미연결 — 자동 실행 시도`);
    try {
      spawnApp(app);
    } catch (error: any) {
      return errorResult(`❌ '${app}' 앱 자동 실행 실패: ${error.message}`, {
        success: false,
        app,
        error: error.message,
      });
    }
    const connected = await waitForAppConnection(app, LAUNCH_WAIT_TIMEOUT_MS);
    if (!connected) {
      return errorResult(
        `❌ '${app}' 앱이 ${LAUNCH_WAIT_TIMEOUT_MS / 1000}초 내에 연결되지 않았습니다.`,
        { success: false, app, error: "not connected" },
      );
    }
  }

  const requestId = crypto.randomUUID();

  // 응답 대기 Promise 를 먼저 등록한다 (targeted /AGENT.FORWARD 직후 바로 해제될 수 있음).
  const waiterPromise = registerForwardWaiter(requestId, {
    timeoutMs: FORWARD_WAIT_TIMEOUT_MS,
    timeoutMessage: `'${app}' 에이전트 응답 대기 타임아웃 (${FORWARD_WAIT_TIMEOUT_MS / 1000}s)`,
  });

  forwardToAgent(app, {
    from: fromAppId,
    to: app,
    message,
    requestId,
    ttl: forwardedTtl,
  });

  try {
    const responseText = (await waiterPromise).trim() || "(응답 없음)";
    return {
      content: [
        { type: "text" as const, text: `💬 '${app}' 응답:\n${responseText}` },
      ],
      details: {
        success: true,
        app,
        mode: "message",
        requestId,
        responseText,
      },
    };
  } catch (error: any) {
    return errorResult(`❌ '${app}' 에이전트 호출 실패: ${error.message}`, {
      success: false,
      app,
      requestId,
      error: error.message,
    });
  }
}

async function runCommandMode(
  app: string,
  command: string,
  cmdParams?: any,
  env?: Record<string, string>,
  args?: string[],
) {
  const isConnected = UserSocketHandler.isAppConnected(app);
  const isShutdown = command === SHUTDOWN_COMMAND;

  if (isShutdown && !isConnected) {
    return {
      content: [
        {
          type: "text" as const,
          text: `ℹ️ '${app}' 앱이 이미 실행되지 않은 상태입니다. SHUTDOWN 을 건너뜁니다.`,
        },
      ],
      details: { app, command, success: true, skipped: true },
    };
  }

  if (!isConnected) {
    logger.info(`[ControlApp:command] '${app}' 미연결 — 자동 실행 시도`);
    try {
      spawnApp(app, env, args);
    } catch (error: any) {
      return errorResult(`❌ '${app}' 앱 자동 실행 실패: ${error.message}`, {
        app,
        command,
        success: false,
        error: error.message,
      });
    }
    const connected = await waitForAppConnection(app, LAUNCH_WAIT_TIMEOUT_MS);
    if (!connected) {
      return errorResult(
        `❌ '${app}' 앱이 ${LAUNCH_WAIT_TIMEOUT_MS / 1000}초 내에 서버에 연결되지 않았습니다.`,
        { app, command, success: false, launched: true, connected: false },
      );
    }
    logger.info(`[ControlApp:command] '${app}' 연결 확인됨`);
  }

  try {
    const result = await commandApp(app, command, cmdParams || {});
    const isAppError = result?.status === "error" || result?.ok === false;

    if (isAppError) {
      return errorResult(
        `❌ '${app}' 앱에서 명령 실행 중 에러: ${result?.message || JSON.stringify(result)}`,
        {
          app,
          command,
          params: cmdParams,
          result,
          success: false,
          error: result?.message,
        },
      );
    }

    return {
      content: [
        {
          type: "text" as const,
          text: `🚀 '${app}' '${command}' 실행 결과:\n${JSON.stringify(result, null, 2)}`,
        },
      ],
      details: { app, command, params: cmdParams, result, success: true },
    };
  } catch (error: any) {
    return errorResult(
      `❌ '${app}' 앱으로 명령 전송 또는 실행 실패: ${error.message}`,
      { app, command, success: false, error: error.message },
    );
  }
}

export const TOOLS = [controlAppTool];
