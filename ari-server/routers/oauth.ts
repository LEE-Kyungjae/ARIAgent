import { randomUUID } from "node:crypto";
import { router } from "../system/router.js";
import {
  startOAuthLogin,
  resolveOAuthPrompt,
  cancelOAuthLogin,
  getOAuthStatus,
  logoutOAuth,
  getAllOAuthAccounts,
  OAUTH_PROVIDER_LABELS,
  type LoginEvent,
} from "../services/oauth/index.js";
import type { OAuthProvider } from "../repositories/oauth_repository.js";
import { logger } from "../infra/logger.js";

// accountId → 현재 활성 loginId. 새 로그인을 시작할 때마다 새 id를 발급한다.
// 이전 attempt의 비동기 콜백(예: 늦게 도착한 error/prompt)을 stale로 판단해 drop하기 위함.
const activeLoginIds = new Map<string, string>();

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

  // 이전 attempt가 아직 살아있을 수 있으므로 cancel + loginId 새로 발급.
  cancelOAuthLogin(accountId);
  const loginId = randomUUID();
  activeLoginIds.set(accountId, loginId);

  logger.info(`[OAuthRouter] Starting OAuth login: ${provider} (${accountId}) loginId=${loginId}`);

  ws.send("/OAUTH_LOGIN", {
    ok: true,
    data: { started: true, accountId, provider, loginId },
  });

  startOAuthLogin(accountId, provider, (event: LoginEvent) => {
    // stale 콜백 차단: 이미 새 attempt가 시작됐거나 cancel된 경우 drop
    if (activeLoginIds.get(accountId) !== loginId) {
      logger.info(
        `[OAuthRouter] Drop stale event for ${accountId}: ${event.type} (loginId=${loginId})`,
      );
      return;
    }
    if (event.type === "done" || event.type === "error") {
      activeLoginIds.delete(accountId);
    }
    ws.send("/OAUTH_EVENT", { accountId, provider, loginId, ...event });
  }).catch((err) => {
    if (activeLoginIds.get(accountId) !== loginId) return;
    activeLoginIds.delete(accountId);
    logger.error(`[OAuthRouter] Unexpected error in login flow for ${provider} (${accountId}):`, err);
    ws.send("/OAUTH_EVENT", {
      accountId,
      provider,
      loginId,
      type: "error",
      message: err?.message || "Unknown error",
    });
  });
});

// ─── 진행 중인 로그인 취소 ──────────────────────────────────
router.on("/OAUTH_CANCEL", async (ws, params) => {
  const accountId = params.accountId as string;
  if (!accountId) {
    return ws.send("/OAUTH_CANCEL", { ok: false, message: "accountId is required" });
  }

  // loginId를 먼저 비워서 이후 들어올 콜백을 모두 stale로 처리.
  activeLoginIds.delete(accountId);
  const cancelled = cancelOAuthLogin(accountId);
  logger.info(`[OAuthRouter] Cancel requested for ${accountId}: ${cancelled ? "resolved" : "no pending prompt"}`);
  ws.send("/OAUTH_CANCEL", { ok: true, data: { accountId, cancelled } });
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
