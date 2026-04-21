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

// ─── 프로바이더별 로그인 플로우 ─────────────────────────────
export async function startOAuthLogin(
  accountId: string,
  provider: OAuthProvider,
  onEvent: LoginProgressCallback,
): Promise<void> {
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
            return waitForPromptReply(accountId);
          },
          onProgress: (message) => {
            onEvent({ type: "progress", message });
          },
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
            return waitForPromptReply(accountId);
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
            return waitForPromptReply(accountId);
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
    logger.error(`[OAuth] Login failed for ${provider} (${accountId}):`, err);
    onEvent({ type: "error", message: err?.message || "로그인 실패" });
  }
}

// ─── prompt 응답을 앱에서 보낼 때 사용 ─────────────────────
function waitForPromptReply(accountId: string): Promise<string> {
  return new Promise<string>((resolve) => {
    pendingPrompts.set(accountId, resolve);
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
// pendingPrompts에 매달려있는 promise를 빈 문자열로 resolve해서 pi-ai 라이브러리의
// onPrompt가 실패 분기로 흘러가게 만든다 → startOAuthLogin이 catch에서 error 이벤트를 emit.
// pendingPrompts에 등록되기 전이라면(브라우저 콜백 대기 등) 서버 측 abort는 불가능하지만
// 클라이언트 상태는 즉시 초기화된다.
export function cancelOAuthLogin(accountId: string): boolean {
  const resolve = pendingPrompts.get(accountId);
  if (!resolve) {
    return false;
  }
  pendingPrompts.delete(accountId);
  resolve(""); // 빈 입력 → pi-ai가 인증 실패로 처리
  return true;
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
