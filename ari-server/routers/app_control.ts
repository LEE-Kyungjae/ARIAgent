import fs from "fs";
import os from "os";
import path from "path";
import { spawn } from "child_process";
import { DATA_DIR, rmDirSyncSafe } from "../infra/data.js";
import { findAppExecutable } from "../infra/runtime_paths.js";
import { router } from "../system/router.js";
import { UserSocketHandler } from "../system/ws.js";
import { notifyInstalledAppsChanged } from "../protocol/app.js";
import { logger } from "../infra/logger.js";
import { initAgent } from "../services/agent/index.js";
import { execPromise } from "../tools/bash.js";
import { sweepPinnedAppFromAllAgents } from "../repositories/agent_repository.js";
import { loadAllApps } from "../skills/index.js";
import { installAppFromUrl } from "../services/app_installer.js";

/**
 * /LAUNCH_APP
 * 특정 앱을 실행합니다.
 */
router.on("/LAUNCH_APP", async (ctx, params) => {
  const { appId } = params as { appId: string };
  logger.info(`[Apps] Launching app: ${appId} from ${ctx.uuid}`);

  if (!appId) {
    return ctx.send("/LAUNCH_APP", { ok: false, error: "appId is required" });
  }

  try {
    if (UserSocketHandler.isAppConnected(appId)) {
      return ctx.send("/LAUNCH_APP", {
        id: params.id,
        ok: true,
        data: { alreadyRunning: true, message: `'${appId}'가 이미 실행 중입니다.` },
      });
    }

    const executable = findAppExecutable(appId);

    if (!executable) {
      throw new Error(`실행 파일을 찾을 수 없습니다: ${appId}`);
    }

    const launchLogDir = path.join(DATA_DIR, "launch-logs");
    fs.mkdirSync(launchLogDir, { recursive: true });
    const launchLogPath = path.join(launchLogDir, `${appId}.log`);
    const stdoutFd = fs.openSync(launchLogPath, "a");
    const stderrFd = fs.openSync(launchLogPath, "a");

    const bundlePath =
      process.platform === "darwin"
        ? executable.split("/Contents/MacOS/")[0]
        : null;
    const launcherExecutable =
      process.platform === "darwin" ? "open" : executable;
    const defaultArgs: string[] = [];
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
      },
    });
    child.on("spawn", () => {
      logger.info(
        `[Apps] Spawned ${appId} (pid: ${child.pid ?? "unknown"}) log: ${launchLogPath}`,
      );
    });
    child.on("exit", (code: number | null, signal: NodeJS.Signals | null) => {
      logger.warn(
        `[Apps] ${appId} exited (code: ${code ?? "null"}, signal: ${signal ?? "null"})`,
      );
    });
    child.on("error", (error: any) => {
      logger.error(`[Apps] Failed to spawn ${appId}: ${error.message}`);
    });
    child.unref();

    ctx.send("/LAUNCH_APP", {
      id: params.id,
      ok: true,
      data: { success: true, message: `'${appId}' 앱을 실행했습니다.` },
    });
  } catch (error: any) {
    logger.error(`[Apps] Failed to launch ${appId}: ${error.message}`);
    ctx.send("/LAUNCH_APP", {
      id: params.id,
      ok: false,
      error: error.message,
    });
  }
});

/**
 * /APP.UPDATE
 * 호스트 앱(ARIAgent 등)을 직접 다운로드·교체·재실행합니다.
 * AI 없이 Flutter 클라이언트가 직접 호출합니다.
 *
 * params:
 *   url              - 새 버전 .zip 다운로드 주소
 *   appName          - 앱 이름 (로그용)
 *   appExecutablePath - 현재 실행 중인 앱의 실행 파일 경로 (Platform.resolvedExecutable)
 */
router.on("/APP.UPDATE", async (ctx, params) => {
  const { url, appName = "app", appExecutablePath } = params as {
    url: string;
    appName: string;
    appExecutablePath: string;
  };

  logger.info(`[AppUpdate] Received update request for '${appName}' from ${url}`);

  if (!url || !appExecutablePath) {
    return ctx.send("/APP.UPDATE", { ok: false, error: "url and appExecutablePath are required" });
  }

  const tempDir = path.join(os.tmpdir(), `ari-host-update-${Date.now()}`);

  try {
    // 1. 임시 디렉토리 준비
    fs.mkdirSync(tempDir, { recursive: true });
    const zipPath = path.join(tempDir, "update.zip");
    const extractDir = path.join(tempDir, "extracted");
    fs.mkdirSync(extractDir, { recursive: true });

    // 2. 다운로드
    ctx.send("/APP.UPDATE.PROGRESS", { stage: "downloading", message: "새 버전 다운로드 중..." });
    logger.info(`[AppUpdate] Downloading to ${zipPath}`);
    await execPromise(`curl -L "${url}" -o "${zipPath}"`);

    // 3. 압축 해제
    ctx.send("/APP.UPDATE.PROGRESS", { stage: "extracting", message: "압축 해제 중..." });
    logger.info(`[AppUpdate] Extracting to ${extractDir}`);
    if (process.platform === "win32") {
      await execPromise(`powershell -Command "Expand-Archive -Path '${zipPath}' -DestinationPath '${extractDir}' -Force"`);
    } else {
      await execPromise(`unzip -o "${zipPath}" -d "${extractDir}"`);
    }

    // 4. 압축 해제 결과에서 앱 번들 찾기
    const findAppBundle = (dir: string): string | null => {
      const items = fs.readdirSync(dir).filter(f => !f.startsWith(".") && f !== "__MACOSX");
      for (const item of items) {
        const itemPath = path.join(dir, item);
        const stat = fs.statSync(itemPath);
        if (process.platform === "darwin" && item.endsWith(".app") && stat.isDirectory()) {
          return itemPath;
        }
        if (process.platform === "win32" && item.endsWith(".exe") && stat.isFile()) {
          return itemPath;
        }
        if (stat.isDirectory()) {
          const found = findAppBundle(itemPath);
          if (found) return found;
        }
      }
      return null;
    };

    const newAppBundle = findAppBundle(extractDir);
    if (!newAppBundle) {
      throw new Error("압축 파일에서 앱 번들(.app / .exe)을 찾을 수 없습니다.");
    }
    logger.info(`[AppUpdate] Found new bundle: ${newAppBundle}`);

    // 5. 현재 앱 번들 경로 계산
    let currentAppBundle: string;
    if (process.platform === "darwin") {
      // e.g. /Applications/ARIAgent.app/Contents/MacOS/ARIAgent → /Applications/ARIAgent.app
      const parts = appExecutablePath.split("/Contents/MacOS/");
      if (parts.length < 2) throw new Error(`올바르지 않은 실행 파일 경로: ${appExecutablePath}`);
      currentAppBundle = parts[0];
    } else {
      currentAppBundle = path.dirname(appExecutablePath);
    }
    logger.info(`[AppUpdate] Current bundle: ${currentAppBundle}`);

    // 플러그인 앱 여부 판별 (DATA_DIR/apps/ 하위에 설치된 서드파티 앱)
    const installParent = path.dirname(currentAppBundle);
    const appsRoot = path.join(DATA_DIR, "apps");
    const isPluginApp = installParent === appsRoot || installParent.startsWith(appsRoot + path.sep);

    const newExeDir = path.dirname(newAppBundle);
    const exeName = path.basename(newAppBundle);
    const targetExePath = path.join(currentAppBundle, exeName);

    ctx.send("/APP.UPDATE.PROGRESS", { stage: "installing", message: "업데이트 설치 중..." });

    if (isPluginApp && process.platform === "win32") {
      // ─── Windows 플러그인 앱 업데이트: 서버가 직접 소켓 close 를 감지해서 Node.js 로 처리 ───
      // Windows bat/ps1 스크립트는 한글 사용자명 경로 인코딩 문제로 실행이 안 될 수 있다.
      // 서버는 SARI 업데이트 후에도 계속 살아있으므로 Node.js 의 네이티브 유니코드 지원을 그대로 쓴다.
      // macOS 는 UTF-8 환경이라 기존 bash 스크립트가 정상 동작하므로 아래 else 분기를 사용한다.
      const backupPath = `${currentAppBundle}_bak_${Date.now()}`;
      const capturedTempDir = tempDir;

      const socket = UserSocketHandler.findSocketByUuid(ctx.uuid);
      const doReplace = () => {
        setTimeout(async () => {
          try {
            if (fs.existsSync(currentAppBundle)) {
              fs.renameSync(currentAppBundle, backupPath);
              logger.info(`[AppUpdate] Renamed old dir → ${backupPath}`);
            }
            fs.renameSync(newExeDir, currentAppBundle);
            logger.info(`[AppUpdate] Moved new version → ${currentAppBundle}`);

            await loadAllApps();
            notifyInstalledAppsChanged(path.basename(currentAppBundle));

            if (fs.existsSync(targetExePath)) {
              const child = spawn(targetExePath, [], { detached: true, stdio: "ignore" });
              child.unref();
              logger.info(`[AppUpdate] Started new version: ${targetExePath}`);
            } else {
              logger.error(`[AppUpdate] Target exe not found: ${targetExePath}`);
            }

            fs.rmSync(backupPath, { recursive: true, force: true });
            if (fs.existsSync(capturedTempDir)) fs.rmSync(capturedTempDir, { recursive: true, force: true });
          } catch (err: any) {
            logger.error(`[AppUpdate] In-process replacement failed: ${err.message}`);
          }
        }, 2000);
      };

      if (socket) {
        socket.once("close", doReplace);
      } else {
        doReplace();
      }

      ctx.send("/APP.UPDATE", { ok: true, data: { message: "업데이트 준비 완료. 앱을 재시작합니다." } });
      logger.info(`[AppUpdate] Plugin update: waiting for client socket to close.`);

    } else {
      // ─── macOS(플러그인 포함) / Windows 호스트 앱: 외부 스크립트 사용 ───
      // macOS 는 UTF-8 환경이라 bash 스크립트가 문제없이 동작한다.
      // Windows 호스트 앱은 서버도 함께 종료되므로 외부 스크립트가 필요하다.
      if (process.platform === "darwin") {
        const scriptPath = path.join(tempDir, "apply_update.sh");
        const script = [
          "#!/bin/bash",
          "sleep 2",
          `rm -rf "${currentAppBundle}"`,
          `mv "${newAppBundle}" "${currentAppBundle}"`,
          `open "${currentAppBundle}"`,
          `rm -rf "${tempDir}"`,
        ].join("\n");
        fs.writeFileSync(scriptPath, script, { mode: 0o755 });
        const child = spawn("bash", [scriptPath], { detached: true, stdio: "ignore" });
        child.unref();
      } else if (process.platform === "win32") {
        const backupPath = `${currentAppBundle}_bak_${Date.now()}`;
        const ps = (p: string) => p.replace(/'/g, "''");
        const script = [
          "Start-Sleep -Seconds 3",
          `$backup = '${ps(backupPath)}'`,
          `$current = '${ps(currentAppBundle)}'`,
          `$newDir = '${ps(newExeDir)}'`,
          `$target = '${ps(targetExePath)}'`,
          "if (Test-Path $backup) { Remove-Item -Recurse -Force $backup -ErrorAction SilentlyContinue }",
          "Rename-Item -Path $current -NewName ([System.IO.Path]::GetFileName($backup)) -ErrorAction SilentlyContinue",
          "if (Test-Path $current) { Remove-Item -Recurse -Force $current -ErrorAction SilentlyContinue }",
          "Move-Item -Path $newDir -Destination $current -ErrorAction SilentlyContinue",
          "if (Test-Path $target) { Start-Process $target }",
          "if (Test-Path $backup) { Remove-Item -Recurse -Force $backup -ErrorAction SilentlyContinue }",
          `Remove-Item -Recurse -Force '${ps(tempDir)}' -ErrorAction SilentlyContinue`,
        ].join("\n");
        const encoded = Buffer.from(script, "utf16le").toString("base64");
        const child = spawn(
          "powershell",
          ["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-EncodedCommand", encoded],
          { detached: true, stdio: "ignore" },
        );
        child.unref();
      }
      ctx.send("/APP.UPDATE", { ok: true, data: { message: "업데이트 준비 완료. 앱을 재시작합니다." } });
      logger.info(`[AppUpdate] Host update script launched. Waiting for client to close.`);
    }

  } catch (error: any) {
    logger.error(`[AppUpdate] Failed: ${error.message}`);
    if (fs.existsSync(tempDir)) fs.rmSync(tempDir, { recursive: true, force: true });
    ctx.send("/APP.UPDATE", { ok: false, error: error.message });
  }
});

/**
 * /APP.INSTALL
 * 에이전트 스토어의 .zip URL 로부터 앱을 다운로드/설치 (Flutter 직접 호출).
 *
 * params:
 *   url    - 설치할 .zip 다운로드 주소
 *   appId  - 앱 식별자 (생략 시 파일명에서 추출)
 *   force  - 버전이 같거나 낮아도 강제 설치
 *
 * 진행 단계는 /APP.INSTALL.PROGRESS 로 stream.
 */
router.on("/APP.INSTALL", async (ctx, params) => {
  const { url, appId, force } = params as {
    url: string;
    appId?: string;
    force?: boolean;
  };

  if (!url) {
    return ctx.send("/APP.INSTALL", {
      id: params.id,
      ok: false,
      error: "url is required",
    });
  }

  const result = await installAppFromUrl({
    url,
    appId,
    force,
    onProgress: (stage, message) => {
      ctx.send("/APP.INSTALL.PROGRESS", { appId, stage, message });
    },
  });

  if (result.success) {
    ctx.send("/APP.INSTALL", { id: params.id, ok: true, data: result });
  } else {
    ctx.send("/APP.INSTALL", {
      id: params.id,
      ok: false,
      error: result.error,
      data: result,
    });
  }
});

router.on("/DELETE_SKILL", async (ctx, params) => {
  const { name } = params;
  logger.info(`[Skills] Deleting skill: ${name}`);
  if (!name) {
    return ctx.send("/DELETE_SKILL", { ok: false, error: "Name is required" });
  }

  try {
    const skillDir = path.join(DATA_DIR, "skills", name);

    if (fs.existsSync(skillDir)) {
      rmDirSyncSafe(skillDir);
      await initAgent();
      logger.info(`[Skills] Skill ${name} deleted and agent re-initialized`);
      ctx.send("/DELETE_SKILL", { ok: true, data: { success: true } });
    } else {
      logger.warn(`[Skills] Skill ${name} not found`);
      ctx.send("/DELETE_SKILL", {
        ok: false,
        error: "Skill not found in user skills",
      });
    }
  } catch (e) {
    logger.error(`[Skills] Error deleting skill ${name}: ${e}`);
    ctx.send("/DELETE_SKILL", { ok: false, error: String(e) });
  }
});

router.on("/DELETE_APP", async (ctx, params) => {
  const { name } = params as { name: string };
  logger.info(`[Apps] Deleting app: ${name}`);
  if (!name) {
    return ctx.send("/DELETE_APP", { ok: false, error: "Name is required" });
  }

  try {
    // 앱은 top-level 엔티티 — 모든 에이전트의 핀 목록에서 청소하고 폴더 삭제
    sweepPinnedAppFromAllAgents(name);

    // SKILL.md frontmatter의 name 과 실제 폴더명이 다를 수 있으므로
    // (예: folder=youtube_player, name=youtube-player)
    // loadAllApps 로 실제 filePath 를 찾아 해당 폴더를 제거한다.
    const apps = await loadAllApps();
    const target = apps.find((a) => a.name === name);
    const targetDir = target ? path.dirname(target.filePath) : null;

    if (targetDir && fs.existsSync(targetDir)) {
      rmDirSyncSafe(targetDir);
      logger.info(`[Apps] App folder '${name}' removed (${targetDir})`);
    } else {
      logger.warn(
        `[Apps] App '${name}' not resolvable to a folder (targetDir=${targetDir ?? "null"})`,
      );
      return ctx.send("/DELETE_APP", {
        ok: false,
        error: `app '${name}' not found on disk`,
      });
    }

    await initAgent();
    ctx.send("/DELETE_APP", { ok: true, data: { success: true } });
    notifyInstalledAppsChanged(name);
  } catch (e) {
    logger.error(`[Apps] Error deleting app ${name}: ${e}`);
    ctx.send("/DELETE_APP", { ok: false, error: String(e) });
  }
});
