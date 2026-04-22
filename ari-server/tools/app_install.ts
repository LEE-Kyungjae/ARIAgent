import { AgentTool } from "@mariozechner/pi-agent-core";
import { Type } from "@mariozechner/pi-ai";
import axios from "axios";
import fs from "fs";
import path from "path";
import { logger } from "../infra/logger.js";
import { DATA_DIR } from "../infra/data.js";
import { notifyInstalledAppsChanged } from "../protocol/app.js";
import { loadAllApps } from "../skills/index.js";
import { execPromise } from "./bash.js";

interface AppInfo {
  app_id: string;
  name: string;
  description: string;
  github_url?: string;
  category?: string;
  mac_download_uri?: string;
  win_download_uri?: string;
}

const CLOUDFRONT_BASE_URL = "https://d34z72svq84n71.cloudfront.net";

export const searchStoreAppTool: AgentTool = {
  name: "search_store_app",
  label: "스토어 앱 검색",
  description:
    "ARI 앱 스토어에서 써드파티 앱을 검색하고 식별자와 설치 다운로드 URL을 얻어옵니다. 사용자가 특정 목적의 앱(예: 주식앱, 날씨앱) 설치를 요청할 때 필수적으로 먼저 호출해야 합니다.",
  parameters: Type.Object({
    searchTerm: Type.String({
      description: "검색어 (예: 주식, 날씨, 메모 등)",
    }),
  }),
  execute: async (_toolCallId, params) => {
    const { searchTerm } = params as { searchTerm: string };
    try {
      logger.info(`[StoreTool] Searching apps with query: "${searchTerm}"`);

      const apiUrl = `https://ariwith.me/api/search-apps?q=${encodeURIComponent(searchTerm)}&limit=5`;
      const { data } = await axios.get(apiUrl);

      if (!data.success) {
        throw new Error(data.error);
      }

      const apps: AppInfo[] = data.data || [];
      if (apps.length === 0) {
        return {
          content: [
            {
              type: "text",
              text: `❌ '${searchTerm}'에 대한 앱 검색 결과가 없습니다.`,
            },
          ],
          details: { searchTerm, apps: [] },
        };
      }

      const isMac = process.platform === "darwin";

      const results = apps.map((app) => {
        let zipUrl = undefined;
        let uri = isMac ? app.mac_download_uri : app.win_download_uri;

        if (uri) {
          zipUrl = `${CLOUDFRONT_BASE_URL}/${uri.replace(/^\//, "")}`;
        }

        return {
          app_id: app.app_id,
          name: app.name,
          description: app.description,
          zip_download_url: zipUrl,
        };
      });

      return {
        content: [
          {
            type: "text",
            text: `✅ 스토어 검색 결과 (${results.length}건):
${JSON.stringify(results, null, 2)}
이 중 원하는 앱을 설치하려면 'install_app' 도구를 호출할 때 'url' 파라미터로 위 내용 중 'zip_download_url'을 전달하세요.`,
          },
        ],
        details: { searchTerm, results },
      };
    } catch (error: any) {
      logger.error(`[StoreTool] Error searching apps: ${error.message}`);
      return {
        content: [
          {
            type: "text",
            text: `❌ 스토어 통신 도중 오류가 발생했습니다: ${error.message}`,
          },
        ],
        details: { ok: false, error: error.message },
      };
    }
  },
};

export const installAppTool: AgentTool = {
  name: "install_app",
  label: "앱 설치 및 업데이트",
  description:
    "외부 URL(.zip)로부터 ARI 앱을 다운로드하여 설치하거나 기존 앱을 업데이트합니다.",
  parameters: Type.Object({
    url: Type.String({ description: "설치할 앱의 .zip 다운로드 주소" }),
    appId: Type.Optional(
      Type.String({ description: "앱의 식별자 (생략 시 파일명에서 추출)" }),
    ),
    force: Type.Optional(
      Type.Boolean({ description: "버전이 같거나 낮아도 강제로 설치합니다." }),
    ),
  }),
  execute: async (_id, params) => {
    const {
      url,
      appId: providedAppId,
      force,
    } = params as { url: string; appId?: string; force?: boolean };

    let appId = providedAppId;
    if (!appId) {
      const urlParts = url.split("/");
      const fileName = urlParts[urlParts.length - 1];
      appId = fileName.split("-")[0].replace(".zip", "");
    }

    logger.info(`[AppInstall] Starting installation for ${appId} from ${url}`);

    const tempDir = path.join(DATA_DIR, "tmp_install", appId);
    const appInstallDir = path.join(DATA_DIR, "apps", appId);

    try {
      if (fs.existsSync(tempDir))
        fs.rmSync(tempDir, { recursive: true, force: true });
      fs.mkdirSync(tempDir, { recursive: true });

      const zipPath = path.join(tempDir, "app.zip");
      logger.info(`[AppInstall] Downloading to ${zipPath}`);
      await execPromise(`curl -L "${url}" -o "${zipPath}"`);

      const extractDir = path.join(tempDir, "extracted");
      fs.mkdirSync(extractDir, { recursive: true });
      logger.info(`[AppInstall] Extracting to ${extractDir}`);

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
              content: [
                {
                  type: "text",
                  text: `ℹ️ 이미 최신 버전(${oldInfo.version})이 설치되어 있습니다.`,
                },
              ],
              details: {
                appId,
                success: true,
                updated: false,
                currentVersion: oldInfo.version,
              },
            };
          }
        } catch (err: any) {
          logger.warn(
            `[AppInstall] Version check comparison failed: ${err.message}`,
          );
        }
      }

      if (fs.existsSync(appInstallDir)) {
        logger.info(`[AppInstall] Removing existing app at ${appInstallDir}`);
        fs.rmSync(appInstallDir, { recursive: true, force: true });
      }
      fs.mkdirSync(path.dirname(appInstallDir), { recursive: true });

      logger.info(`[AppInstall] Moving ${sourceDir} to ${appInstallDir}`);
      fs.renameSync(sourceDir, appInstallDir);

      await loadAllApps();

      notifyInstalledAppsChanged(appId);

      return {
        content: [
          {
            type: "text",
            text: `✅ '${appId}' 앱이 성공적으로 설치(업데이트)되었습니다.`,
          },
        ],
        details: { appId, success: true },
      };
    } catch (error: any) {
      logger.error(`[AppInstall] Failed to install ${appId}: ${error.message}`);
      return {
        content: [
          {
            type: "text",
            text: `❌ '${appId}' 앱 설치 중 오류 발생: ${error.message}`,
          },
        ],
        details: { appId, success: false, error: error.message },
      };
    } finally {
      if (fs.existsSync(tempDir))
        fs.rmSync(tempDir, { recursive: true, force: true });
    }
  },
};

export const TOOLS = [searchStoreAppTool, installAppTool];
