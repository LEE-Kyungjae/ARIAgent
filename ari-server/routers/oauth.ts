import { router } from "../system/router.js";
import {
  startOAuthLogin,
  resolveOAuthPrompt,
  getOAuthStatus,
  logoutOAuth,
  getAllOAuthAccounts,
  OAUTH_PROVIDER_LABELS,
  type LoginEvent,
} from "../services/oauth/index.js";
import type { OAuthProvider } from "../repositories/oauth_repository.js";
import { logger } from "../infra/logger.js";

// ─── 저장된 OAuth 계정 목록 조회 ───────────────────────────
router.on("/OAUTH_PROVIDERS", async (ws, _params) => {
  const accounts = getAllOAuthAccounts();
  ws.send("/OAUTH_PROVIDERS", {
    ok: true,
    data: { accounts },
  });
});

// ─── 로그인 플로우 시작 ──────────────────────────────────────
// 로그인 진행 이벤트는 별도의 push 메시지(/OAUTH_EVENT)로 앱에 전송
router.on("/OAUTH_LOGIN", async (ws, params) => {
  const accountId = params.accountId as string;
  const provider = params.provider as OAuthProvider;
  if (!accountId || !provider) {
    return ws.send("/OAUTH_LOGIN", { ok: false, message: "accountId and provider are required" });
  }

  logger.info(`[OAuthRouter] Starting OAuth login: ${provider} (${accountId})`);

  // 즉시 시작 응답 후 비동기 로그인 실행
  ws.send("/OAUTH_LOGIN", { ok: true, data: { started: true, accountId, provider } });

  startOAuthLogin(accountId, provider, (event: LoginEvent) => {
    ws.send("/OAUTH_EVENT", { accountId, provider, ...event });
  }).catch((err) => {
    logger.error(`[OAuthRouter] Unexpected error in login flow for ${provider} (${accountId}):`, err);
    ws.send("/OAUTH_EVENT", {
      accountId,
      provider,
      type: "error",
      message: err?.message || "Unknown error",
    });
  });
});

// ─── 사용자 입력(코드) 전달 ──────────────────────────────────
router.on("/OAUTH_PROMPT", async (ws, params) => {
  const accountId = params.accountId as string;
  const value = params.value as string;

  if (!accountId || value === undefined) {
    return ws.send("/OAUTH_PROMPT", { ok: false, message: "accountId and value are required" });
  }

  const resolved = resolveOAuthPrompt(accountId, value);
  ws.send("/OAUTH_PROMPT", { ok: true, data: { resolved } });
});

// ─── 특정 계정 로그인 상태 조회 ─────────────────────
router.on("/OAUTH_STATUS", async (ws, params) => {
  const accountId = params.accountId as string;
  if (!accountId) {
    return ws.send("/OAUTH_STATUS", { ok: false, message: "accountId is required" });
  }

  const status = getOAuthStatus(accountId);
  ws.send("/OAUTH_STATUS", {
    ok: true,
    data: {
      accountId: status.accountId,
      loggedIn: status.loggedIn,
      provider: status.provider,
      label: status.provider ? OAUTH_PROVIDER_LABELS[status.provider] : null,
    },
  });
});

// ─── 로그아웃 ──────────────────────────────────────────────
router.on("/OAUTH_LOGOUT", async (ws, params) => {
  const accountId = params.accountId as string;
  if (!accountId) {
    return ws.send("/OAUTH_LOGOUT", { ok: false, message: "accountId is required" });
  }

  logoutOAuth(accountId);
  ws.send("/OAUTH_LOGOUT", { ok: true, data: { accountId, loggedOut: true } });
});
