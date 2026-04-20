import fs from "fs";
import path from "path";
import os from "os";
import https from "https";
import { createRequire } from "module";
import { spawnSync } from "child_process";
import { logger } from "../infra/logger.js";

declare const __PLAYWRIGHT_RUNTIME_VERSION__: string;

function resolvePlaywrightVersion(): string {
  if (typeof __PLAYWRIGHT_RUNTIME_VERSION__ !== "undefined") {
    return __PLAYWRIGHT_RUNTIME_VERSION__;
  }
  // Dev mode (tsx): playwright lives in local node_modules, read its package.json.
  try {
    const req = createRequire(import.meta.url);
    return (req("playwright/package.json") as { version: string }).version;
  } catch {
    return "0.0.0";
  }
}

const PLAYWRIGHT_VERSION = resolvePlaywrightVersion();
const CDN_BASE = "https://d34z72svq84n71.cloudfront.net/releases/runtime";
const FAILURE_COOLDOWN_MS = 30_000;

function runtimeDir(): string {
  return path.join(os.homedir(), ".ari-agent", "runtime", "playwright");
}

function tarballName(): string {
  return `playwright-${process.platform}-${process.arch}-v${PLAYWRIGHT_VERSION}.tar.gz`;
}

function isInstalled(): boolean {
  const dir = runtimeDir();
  const versionFile = path.join(dir, ".version");
  const pwPkg = path.join(dir, "node_modules", "playwright", "package.json");
  if (!fs.existsSync(versionFile) || !fs.existsSync(pwPkg)) return false;
  try {
    return fs.readFileSync(versionFile, "utf8").trim() === PLAYWRIGHT_VERSION;
  } catch {
    return false;
  }
}

let installPromise: Promise<void> | null = null;
let lastFailure: { at: number; error: string } | null = null;

function downloadFile(url: string, dest: string): Promise<void> {
  return new Promise((resolve, reject) => {
    const file = fs.createWriteStream(dest);
    let settled = false;
    const finish = (err?: Error) => {
      if (settled) return;
      settled = true;
      file.close(() => {
        if (err) {
          fs.rmSync(dest, { force: true });
          reject(err);
        } else {
          resolve();
        }
      });
    };

    const request = (target: string, redirects: number) => {
      if (redirects > 5) {
        finish(new Error(`Too many redirects for ${url}`));
        return;
      }
      https
        .get(
          target,
          {
            // AWS WAF at CloudFront blocks requests with no User-Agent.
            headers: { "User-Agent": "ari-agent-runtime-loader/1.0" },
          },
          (res) => {
          const status = res.statusCode ?? 0;
          if (status >= 300 && status < 400 && res.headers.location) {
            res.resume();
            request(res.headers.location, redirects + 1);
            return;
          }
          if (status !== 200) {
            res.resume();
            finish(new Error(`HTTP ${status} for ${target}`));
            return;
          }
          res.pipe(file);
          file.on("finish", () => finish());
        })
        .on("error", (err) => finish(err));
    };

    file.on("error", (err) => finish(err));
    request(url, 0);
  });
}

async function runInstall(): Promise<void> {
  const dir = runtimeDir();
  const tmpFile = path.join(os.tmpdir(), `ari-playwright-${Date.now()}-${process.pid}.tar.gz`);
  const url = `${CDN_BASE}/${tarballName()}`;

  logger.info(`[PlaywrightRuntime] Downloading ${url} → ${tmpFile}`);
  await downloadFile(url, tmpFile);

  fs.rmSync(dir, { recursive: true, force: true });
  fs.mkdirSync(dir, { recursive: true });

  logger.info(`[PlaywrightRuntime] Extracting to ${dir}`);
  const tarCmd = process.platform === "win32" ? "tar.exe" : "tar";
  const result = spawnSync(tarCmd, ["-xzf", tmpFile, "-C", dir], { stdio: "inherit" });
  fs.rmSync(tmpFile, { force: true });
  if (result.status !== 0) {
    fs.rmSync(dir, { recursive: true, force: true });
    throw new Error(`tar extract failed (exit ${result.status})`);
  }

  fs.writeFileSync(path.join(dir, ".version"), PLAYWRIGHT_VERSION);
  logger.info(`[PlaywrightRuntime] Installed playwright v${PLAYWRIGHT_VERSION}`);
}

export type PlaywrightReadyResult =
  | { ready: true }
  | { ready: false; message: string };

export function ensurePlaywrightRuntime(): PlaywrightReadyResult {
  if (isInstalled()) return { ready: true };

  if (installPromise) {
    return {
      ready: false,
      message: "⏳ 웹 브라우저 런타임 다운로드가 진행 중입니다(~15MB). 잠시 후 다시 시도해주세요.",
    };
  }

  if (lastFailure && Date.now() - lastFailure.at < FAILURE_COOLDOWN_MS) {
    return {
      ready: false,
      message: "❌ 웹 브라우저 런타임 다운로드에 실패했습니다. 네트워크 연결을 확인한 뒤 다시 시도해 주세요.",
    };
  }

  installPromise = runInstall()
    .then(() => {
      lastFailure = null;
    })
    .catch((err: unknown) => {
      const message = err instanceof Error ? err.message : String(err);
      logger.error("[PlaywrightRuntime] install failed:", err);
      lastFailure = { at: Date.now(), error: message };
    })
    .finally(() => {
      installPromise = null;
    });

  return {
    ready: false,
    message: "⏳ 웹 브라우저 런타임 최초 설치를 시작했습니다(~15MB). 설치가 끝나면 다시 호출해주세요.",
  };
}

let cachedPlaywright: typeof import("playwright") | null = null;

export function loadPlaywright(): typeof import("playwright") {
  if (cachedPlaywright) return cachedPlaywright;

  const dir = runtimeDir();
  const localNodeModules = path.join(dir, "node_modules", "playwright");

  if (fs.existsSync(localNodeModules)) {
    // SEA/standalone or installed runtime: resolve via createRequire anchored in runtimeDir.
    const anchor = path.join(dir, ".loader.cjs");
    if (!fs.existsSync(anchor)) {
      fs.writeFileSync(anchor, "// createRequire anchor\n");
    }
    const req = createRequire(anchor);
    cachedPlaywright = req("playwright") as typeof import("playwright");
    return cachedPlaywright;
  }

  // Dev mode: playwright is in the project's node_modules.
  const req = createRequire(import.meta.url);
  cachedPlaywright = req("playwright") as typeof import("playwright");
  return cachedPlaywright;
}
