import fs from "fs";
import { chromium } from "playwright";
import { logger } from "../infra/logger.js";

export type ChromiumReadyResult =
  | { ready: true }
  | { ready: false; message: string };

let installPromise: Promise<void> | null = null;
let lastFailure: { at: number; error: string } | null = null;
const FAILURE_COOLDOWN_MS = 30_000;

function chromiumIsInstalled(): boolean {
  try {
    const execPath = chromium.executablePath();
    return !!execPath && fs.existsSync(execPath);
  } catch {
    return false;
  }
}

async function runInstall(): Promise<void> {
  logger.info("[ChromiumSetup] Starting Chromium download (~170MB, first time only)...");
  // Playwright-core's internal registry — same machinery `npx playwright install` uses.
  // If the internal path shifts on a future Playwright upgrade, the catch in
  // ensureChromiumReady() surfaces the error cleanly to the caller.
  // @ts-ignore — internal path, no type declarations
  const mod: any = await import("playwright-core/lib/server/registry/index.js");
  const registry = mod.registry ?? mod.default?.registry;
  if (!registry || typeof registry.install !== "function") {
    throw new Error("Playwright registry API unavailable — internal API may have changed");
  }
  await registry.install(["chromium"]);
  logger.info("[ChromiumSetup] Chromium installed successfully");
}

export function ensureChromiumReady(): ChromiumReadyResult {
  if (chromiumIsInstalled()) {
    return { ready: true };
  }

  if (installPromise) {
    return {
      ready: false,
      message:
        "⏳ 웹 브라우저 최초 설치가 진행 중입니다(~170MB, 1~2분 소요). 잠시 후 다시 시도해주세요.",
    };
  }

  if (lastFailure && Date.now() - lastFailure.at < FAILURE_COOLDOWN_MS) {
    return {
      ready: false,
      message: `❌ 직전 브라우저 다운로드가 실패했습니다: ${lastFailure.error}. 잠시 후 다시 시도해주세요.`,
    };
  }

  installPromise = runInstall()
    .then(() => {
      lastFailure = null;
    })
    .catch((err: unknown) => {
      const message = err instanceof Error ? err.message : String(err);
      logger.error("[ChromiumSetup] Chromium install failed:", err);
      lastFailure = { at: Date.now(), error: message };
    })
    .finally(() => {
      installPromise = null;
    });

  return {
    ready: false,
    message:
      "⏳ 웹 브라우저 최초 설치를 시작했습니다(~170MB, 1~2분 소요). 설치가 끝나면 다시 호출해주세요.",
  };
}
