import fs from "fs";
import path from "path";
import { logger } from "../infra/logger.js";
import { DATA_DIR } from "../infra/data.js";
import { notifyInstalledAppsChanged } from "../protocol/app.js";
import { loadAllApps } from "../skills/index.js";
import { execPromise } from "../tools/bash.js";

export type InstallProgressStage = "downloading" | "extracting" | "installing";

export type InstallProgressCallback = (
  stage: InstallProgressStage,
  message: string,
) => void;

export interface InstallAppResult {
  appId: string;
  success: boolean;
  updated: boolean;
  currentVersion?: string;
  error?: string;
}

function resolveAppIdFromUrl(url: string): string {
  const fileName = url.split("/").pop() ?? "";
  return fileName.split("-")[0].replace(".zip", "");
}

/**
 * URL의 .zip을 다운로드해 DATA_DIR/apps/<appId>/ 에 설치(또는 업데이트).
 * 설치 후 loadAllApps + notifyInstalledAppsChanged 까지 처리한다.
 */
export async function installAppFromUrl(opts: {
  url: string;
  appId?: string;
  force?: boolean;
  onProgress?: InstallProgressCallback;
}): Promise<InstallAppResult> {
  const { url, force, onProgress } = opts;
  const appId = opts.appId ?? resolveAppIdFromUrl(url);

  logger.info(`[AppInstaller] Starting installation for ${appId} from ${url}`);

  const tempDir = path.join(DATA_DIR, "tmp_install", appId);
  const appInstallDir = path.join(DATA_DIR, "apps", appId);

  try {
    if (fs.existsSync(tempDir))
      fs.rmSync(tempDir, { recursive: true, force: true });
    fs.mkdirSync(tempDir, { recursive: true });

    const zipPath = path.join(tempDir, "app.zip");
    onProgress?.("downloading", "다운로드 중...");
    logger.info(`[AppInstaller] Downloading to ${zipPath}`);
    await execPromise(`curl -L "${url}" -o "${zipPath}"`);

    const extractDir = path.join(tempDir, "extracted");
    fs.mkdirSync(extractDir, { recursive: true });
    onProgress?.("extracting", "압축 해제 중...");
    logger.info(`[AppInstaller] Extracting to ${extractDir}`);

    if (process.platform === "win32") {
      await execPromise(
        `powershell -Command "Expand-Archive -Path '${zipPath}' -DestinationPath '${extractDir}' -Force"`,
      );
    } else {
      await execPromise(`unzip -o "${zipPath}" -d "${extractDir}"`);
    }

    let sourceDir = extractDir;
    const items = fs
      .readdirSync(extractDir)
      .filter((f) => !f.startsWith(".") && f !== "__MACOSX");

    if (
      items.length === 1 &&
      fs.statSync(path.join(extractDir, items[0])).isDirectory()
    ) {
      sourceDir = path.join(extractDir, items[0]);
    }

    const newInfoPath = path.join(sourceDir, "app_info.json");
    const oldInfoPath = path.join(appInstallDir, "app_info.json");

    if (fs.existsSync(newInfoPath) && fs.existsSync(oldInfoPath)) {
      try {
        const newInfo = JSON.parse(fs.readFileSync(newInfoPath, "utf-8"));
        const oldInfo = JSON.parse(fs.readFileSync(oldInfoPath, "utf-8"));

        const newVer = newInfo.version_code ?? newInfo.version;
        const oldVer = oldInfo.version_code ?? oldInfo.version;

        if (newVer <= oldVer && !force) {
          return {
            appId,
            success: true,
            updated: false,
            currentVersion: oldInfo.version,
          };
        }
      } catch (err: any) {
        logger.warn(
          `[AppInstaller] Version check comparison failed: ${err.message}`,
        );
      }
    }

    onProgress?.("installing", "설치 중...");

    if (fs.existsSync(appInstallDir)) {
      logger.info(`[AppInstaller] Removing existing app at ${appInstallDir}`);
      fs.rmSync(appInstallDir, { recursive: true, force: true });
    }
    fs.mkdirSync(path.dirname(appInstallDir), { recursive: true });

    logger.info(`[AppInstaller] Moving ${sourceDir} to ${appInstallDir}`);
    fs.renameSync(sourceDir, appInstallDir);

    await loadAllApps();
    notifyInstalledAppsChanged(appId);

    return { appId, success: true, updated: true };
  } catch (error: any) {
    logger.error(
      `[AppInstaller] Failed to install ${appId}: ${error.message}`,
    );
    return {
      appId,
      success: false,
      updated: false,
      error: error.message,
    };
  } finally {
    if (fs.existsSync(tempDir))
      fs.rmSync(tempDir, { recursive: true, force: true });
  }
}
