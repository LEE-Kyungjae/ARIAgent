import { loginOpenAICodex, loginAnthropic, loginGitHubCopilot, loginGeminiCli, loginAntigravity, getOAuthApiKey } from "@mariozechner/pi-ai";
import type { OAuthCredentials as PiOAuthCredentials } from "@mariozechner/pi-ai";
import { type OAuthProvider, getEntry, setEntry, deleteEntry, listEntries } from "../../repositories/oauth_repository.js";
import { logger } from "../../infra/logger.js";

// ─── 프로바이더별 표시명 ─────────────────────────────────────
export const OAUTH_PROVIDER_LABELS: Record<OAuthProvider, string> = {
  "openai-codex": "OpenAI Codex",
  anthropic: "Anthropic (OAuth)",
  "github-copilot": "GitHub Copilot",
  "google-gemini-cli": "Google Gemini CLI",
  "google-antigravity": "Antigravity",
};

// ─── 로그인 이벤트 ─────────────────────────────────────────
export type LoginEvent =
  | { type: "auth_url"; authUrl: string; instructions?: string }
  | { type: "prompt"; promptMessage: string }
  | { type: "progress"; message: string }
  | { type: "done"; message: string }
  | { type: "error"; message: string };

type LoginProgressCallback = (event: LoginEvent) => void;

// ─── 현재 진행 중인 로그인 플로우의 prompt 대기 큐 ─────────
// accountId 단위로 대기. 같은 provider라도 account별로 독립.
const pendingPrompts: Map<string, (value: string) => void> = new Map();

// ─── 진행 중인 로그인 플로우 추적 ───────────────────────────
// pi-ai의 loginOpenAICodex/loginGeminiCli/loginAntigravity는 OAuth 콜백용으로
// 고정 포트(1455/8085/51121)에 HTTP 서버를 바인딩한다. 사용자가 클라이언트에서
// 취소해도 server.waitForCode가 최대 60초 동안 polling을 계속해서 포트가 풀리지 않고,
// 그 사이 새로 시작한 플로우는 포트 바인드 실패 → onPrompt 폴백으로 빠지게 된다.
//
// 해결: pi-ai의 onManualCodeInput을 abort 핸들로 사용한다. 영원히 resolve되지 않는
// promise를 넘기고, 취소 시 reject → pi-ai의 race가 throw → finally의 server.close()
// 가 실행되어 포트가 즉시 풀린다.
//
// provider 단위로 추적: 같은 provider는 동일 포트를 공유하므로 동시에 하나만 가능.
// 새 플로우 시작 시 같은 provider의 기존 플로우를 먼저 중단하고 정리될 때까지 기다린다.
interface ActiveFlow {
  accountId: string;
  abort: AbortController;
  done: Promise<void>;
}
const activeFlowsByProvider: Map<OAuthProvider, ActiveFlow> = new Map();

// abort 시그널로 reject되는 영원한 promise — pi-ai의 onManualCodeInput 자리에 넣는다.
function makeAbortableManualInput(signal: AbortSignal): () => Promise<string> {
  return () =>
    new Promise<string>((_, reject) => {
      if (signal.aborted) {
        reject(new Error("Login aborted"));
        return;
      }
      const onAbort = () => reject(new Error("Login aborted"));
      signal.addEventListener("abort", onAbort, { once: true });
    });
}

// ─── 프로바이더별 로그인 플로우 ─────────────────────────────
export async function startOAuthLogin(
  accountId: string,
  provider: OAuthProvider,
  onEvent: LoginProgressCallback,
): Promise<void> {
  // 같은 provider의 기존 플로우가 있으면 먼저 중단하고 정리될 때까지 대기.
  // (콜백 포트를 풀어주기 위함 — 그래야 새 플로우가 정상적으로 바인드 가능)
  const existing = activeFlowsByProvider.get(provider);
  if (existing) {
    logger.info(`[OAuth] Aborting existing ${provider} flow (was accountId=${existing.accountId})`);
    existing.abort.abort();
    activeFlowsByProvider.delete(provider);
    try {
      await existing.done;
    } catch {
      // ignore — abort은 reject를 유발할 수 있음
    }
  }

  const abort = new AbortController();
  const manualInput = makeAbortableManualInput(abort.signal);

  const flow = (async () => {
    let credentials: PiOAuthCredentials;
    try {
      switch (provider) {
        case "openai-codex":
          credentials = await loginOpenAICodex({
            onAuth: (info) => {
              logger.info(`[OAuth] Auth URL for openai-codex (${accountId}): ${info.url}`);
              onEvent({ type: "auth_url", authUrl: info.url, instructions: info.instructions });
            },
            onPrompt: async (prompt) => {
              logger.info(`[OAuth] Prompt for openai-codex (${accountId}): ${prompt.message}`);
              onEvent({ type: "prompt", promptMessage: prompt.message });
              return waitForPromptReply(accountId, abort.signal);
            },
            onProgress: (message) => {
              onEvent({ type: "progress", message });
            },
            onManualCodeInput: manualInput,
          });
          break;

        case "anthropic":
          credentials = await loginAnthropic(
            (url) => {
              logger.info(`[OAuth] Auth URL for anthropic (${accountId}): ${url}`);
              onEvent({ type: "auth_url", authUrl: url });
            },
            async () => {
              onEvent({ type: "prompt", promptMessage: "인증 코드를 입력하세요" });
              return waitForPromptReply(accountId, abort.signal);
            },
          );
          break;

        case "github-copilot":
          credentials = await loginGitHubCopilot({
            onAuth: (url, instructions) => {
              logger.info(`[OAuth] Auth URL for github-copilot (${accountId}): ${url}`);
              onEvent({ type: "auth_url", authUrl: url, instructions });
            },
            onPrompt: async (prompt) => {
              onEvent({ type: "prompt", promptMessage: prompt.message });
              return waitForPromptReply(accountId, abort.signal);
            },
            onProgress: (message) => {
              onEvent({ type: "progress", message });
            },
          });
          break;

        case "google-gemini-cli":
          credentials = await loginGeminiCli(
            (info) => {
              logger.info(`[OAuth] Auth URL for google-gemini-cli (${accountId}): ${info.url}`);
              onEvent({ type: "auth_url", authUrl: info.url, instructions: info.instructions });
            },
            (message) => {
              onEvent({ type: "progress", message });
            },
            manualInput,
          );
          break;

        case "google-antigravity":
          credentials = await loginAntigravity(
            (info) => {
              logger.info(`[OAuth] Auth URL for google-antigravity (${accountId}): ${info.url}`);
              onEvent({ type: "auth_url", authUrl: info.url, instructions: info.instructions });
            },
            (message) => {
              onEvent({ type: "progress", message });
            },
            manualInput,
          );
          break;

        default:
          throw new Error(`Unsupported OAuth provider: ${provider}`);
      }

      setEntry(accountId, {
        provider,
        credentials: { type: "oauth", ...credentials },
      });
      logger.info(`[OAuth] Login successful for ${provider} (${accountId})`);
      onEvent({ type: "done", message: "로그인 완료" });
    } catch (err: any) {
      if (abort.signal.aborted) {
        // 사용자 취소로 인한 abort — error 이벤트를 emit하지 않음.
        logger.info(`[OAuth] Login aborted for ${provider} (${accountId})`);
        return;
      }
      logger.error(`[OAuth] Login failed for ${provider} (${accountId}):`, err);
      onEvent({ type: "error", message: err?.message || "로그인 실패" });
    } finally {
      // 자기 자신만 정리 (사이에 다른 플로우가 들어왔으면 그건 건드리지 않음).
      const cur = activeFlowsByProvider.get(provider);
      if (cur && cur.abort === abort) {
        activeFlowsByProvider.delete(provider);
      }
      // pending prompt도 자기 것이면 정리 (race 보호).
      pendingPrompts.delete(accountId);
    }
  })();

  activeFlowsByProvider.set(provider, { accountId, abort, done: flow });
  return flow;
}

// ─── prompt 응답을 앱에서 보낼 때 사용 ─────────────────────
function waitForPromptReply(accountId: string, signal: AbortSignal): Promise<string> {
  return new Promise<string>((resolve, reject) => {
    if (signal.aborted) {
      reject(new Error("Login aborted"));
      return;
    }
    pendingPrompts.set(accountId, resolve);
    signal.addEventListener(
      "abort",
      () => {
        pendingPrompts.delete(accountId);
        reject(new Error("Login aborted"));
      },
      { once: true },
    );
  });
}

export function resolveOAuthPrompt(accountId: string, value: string): boolean {
  const resolve = pendingPrompts.get(accountId);
  if (resolve) {
    pendingPrompts.delete(accountId);
    resolve(value);
    return true;
  }
  return false;
}

// 진행 중인 OAuth 로그인을 취소한다.
// AbortController로 시그널을 보내면 pi-ai의 onManualCodeInput promise가 reject되어
// loginXXX 함수의 finally에서 server.close()가 실행 → 콜백 포트가 즉시 풀린다.
// flow.done을 await해서 정리가 완전히 끝난 뒤 리턴 (이후 시작될 새 플로우와의 race 방지).
export async function cancelOAuthLogin(accountId: string): Promise<boolean> {
  let aborted = false;
  for (const [provider, flow] of activeFlowsByProvider.entries()) {
    if (flow.accountId === accountId) {
      logger.info(`[OAuth] Cancel: aborting ${provider} flow for accountId=${accountId}`);
      flow.abort.abort();
      activeFlowsByProvider.delete(provider);
      try {
        await flow.done;
      } catch {
        // ignore
      }
      aborted = true;
    }
  }
  // pending prompt는 abort 시그널 리스너에서 정리되지만, 안전망으로 한 번 더 확인.
  if (pendingPrompts.delete(accountId)) {
    aborted = true;
  }
  return aborted;
}

// ─── 저장된 credentials로 API Key 획득 (자동 토큰 갱신) ────
export async function getOAuthApiKeyForAccount(accountId: string): Promise<string | null> {
  const entry = getEntry(accountId);
  if (!entry) return null;

  const { provider, credentials } = entry;
  // pi-ai 라이브러리는 { [provider]: credentials } 맵을 받는다
  const credMap = { [provider]: credentials } as any;

  try {
    const result = await getOAuthApiKey(provider as any, credMap);
    if (!result) {
      logger.warn(`[OAuth] getOAuthApiKey returned null for ${provider} (${accountId})`);
      return null;
    }

    // 갱신된 credentials가 있으면 저장
    if (result.newCredentials) {
      setEntry(accountId, {
        provider,
        credentials: { type: "oauth", ...result.newCredentials },
      });
    }

    return result.apiKey;
  } catch (err) {
    logger.error(`[OAuth] Failed to get API key for ${provider} (${accountId}):`, err);
    return null;
  }
}

// ─── 로그인 상태 확인 ────────────────────────────────────────
export function getOAuthStatus(accountId: string): {
  loggedIn: boolean;
  accountId: string;
  provider: OAuthProvider | null;
} {
  const entry = getEntry(accountId);
  return {
    accountId,
    loggedIn: !!entry,
    provider: entry?.provider ?? null,
  };
}

// ─── 로그아웃 ────────────────────────────────────────────────
export function logoutOAuth(accountId: string): void {
  deleteEntry(accountId);
  logger.info(`[OAuth] Logged out account ${accountId}`);
}

// ─── 저장된 계정 전체 상태 ────────────────────────────────
export function getAllOAuthAccounts() {
  return listEntries().map((e) => ({
    accountId: e.accountId,
    provider: e.provider,
    label: OAUTH_PROVIDER_LABELS[e.provider],
    loggedIn: true,
  }));
}
