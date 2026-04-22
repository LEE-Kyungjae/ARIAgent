import { router } from "../system/router.js";
import { UserSocketHandler } from "../system/ws.js";
import { logger } from "../infra/logger.js";
import { getCurrentState, getPluginsInfo } from "../services/agent/index.js";
import { getSettings } from "../repositories/setting_repository.js";
import { Settings } from "../models/settings.js";
import { getEmbeddingStatus } from "../infra/embedding.js";
import { commandApp, notifyConnectedAppsChanged } from "../protocol/app.js";

/**
 * 실시간 연결된 앱 목록을 ari 소켓에 전송 (대시보드 갱신용).
 * ws.ts 의 소켓 close/error 및 아래 /APP.REGISTER 에서 호출된다.
 */
function broadcastConnectedApps(): void {
  notifyConnectedAppsChanged(UserSocketHandler.getConnectedAppIds());
}

UserSocketHandler.setOnAppConnectionChanged(broadcastConnectedApps);

router.on("/HEALTH", async (ctx) => {
  logger.info(`[Health] Check from ${ctx.uuid}`);
  const state = getCurrentState();
  const plugins = await getPluginsInfo();
  const settings = getSettings(new Settings());
  const embStatus = getEmbeddingStatus();
  ctx.send("/HEALTH", {
    ok: true,
    data: {
      status: "ok",
      hasApiKey: state.availableProviders.length > 0,
      isSetupMode: state.availableProviders.length > 0 &&
        state.availableProviders.every((p: any) => p.provider === "ari-cloud"),
      providers: (state.providers || []).map((p: any) => ({
        provider: p.provider,
        model: p.model,
        hasApiKey: !!p.apiKey,
        authType: p.authType,
        accountId: p.accountId,
      })),
      model: state.currentModel,
      provider: state.currentProvider,
      engine: "pi-agent-core",
      tools: plugins.tools.map((t) => t.name),
      skills: plugins.skills.map((s) => s.name),
      useAdvancedMemory: settings.USE_ADVANCED_MEMORY,
      embeddingModelStatus: embStatus.status,
    },
  });
});

/**
 * /GET_CONNECTED_APPS
 * 현재 서버에 활성 상태로 연결된 앱 ID 목록을 반환합니다.
 */
router.on("/GET_CONNECTED_APPS", async (ctx, params) => {
  const connectedIds = UserSocketHandler.getConnectedAppIds();
  ctx.send("/GET_CONNECTED_APPS", {
    id: params.id,
    ok: true,
    data: { connectedIds },
  });
});

/**
 * /APP.REGISTER
 * 앱이 자신을 서버에 등록하고 상태를 보고할 때 사용 (Standardized)
 *
 * 1 앱 = 1 소켓 원칙:
 * - 동일 appId 가 이미 연결되어 있으면 기존 소켓을 살아있는지 확인.
 * - 살아있음 → 새 등록 거부 (중복 인스턴스 차단).
 * - 죽음 → 기존 정리 후 새 소켓 수락 (재접속 시나리오).
 */
router.on("/APP.REGISTER", (ctx, params) => {
  const { appId } = params;
  if (!appId) {
    return ctx.send("/APP.REGISTER", { ok: false, message: "appId required" });
  }

  // 자기 자신이 재등록하는 경우(같은 소켓에서 다시 /APP.REGISTER) 는 통과
  const existing = UserSocketHandler.findSocketByAppId(appId);
  if (existing && existing.uuid !== ctx.uuid) {
    if (UserSocketHandler.isSocketAlive(existing)) {
      logger.warn(
        `[AppSync] Rejected duplicate register for '${appId}' (existing uuid=${existing.uuid} alive)`,
      );
      return ctx.send("/APP.REGISTER", {
        ok: false,
        message: `App '${appId}' is already connected.`,
      });
    }
    // 죽은 좀비 소켓 정리
    logger.info(
      `[AppSync] Cleaning up stale socket for '${appId}' (uuid=${existing.uuid})`,
    );
    UserSocketHandler.dropSocket(existing);
  }

  // 소켓에 appId만 식별용으로 바인딩 (Pull 방식을 위해).
  // 페르소나는 소켓 수명 동안 서버에 저장하지 않는다 — 매 /AGENT 호출 시 페이로드로 동봉.
  ctx.appId = appId;
  logger.info(`[AppSync] App registered: ${appId}`);

  // 연결된 앱 목록 브로드캐스트
  broadcastConnectedApps();

  // 성공 응답
  ctx.send("/APP.REGISTER", { ok: true, data: { appId } });
});

/**
 * /APP.CALL
 * 외부 클라이언트(debug tool 등)가 특정 앱에 명령을 직접 호출할 때 사용.
 * commandApp()을 호출하고 결과를 요청자에게 돌려줍니다.
 */
router.on("/APP.CALL", async (ctx, params) => {
  const { appId, command, params: cmdParams = {}, requestId } = params;

  if (!appId || !command) {
    return ctx.send("/APP.CALL", {
      requestId,
      ok: false,
      message: "appId and command are required",
    });
  }

  try {
    const result = await commandApp(appId, command, cmdParams);
    ctx.send("/APP.CALL", { requestId, ok: true, result });
  } catch (err: any) {
    ctx.send("/APP.CALL", { requestId, ok: false, message: err.message });
  }
});

/**
 * /APP.COMMAND_RESPONSE
 * 명령 실행 후 앱으로부터 결과를 받을 때 (동기식 commandApp 호출의 응답)
 */
router.on("/APP.COMMAND_RESPONSE", (ctx, params) => {
  const { requestId, result } = params;
  const appId = ctx.appId || "unknown";
  
  // 결과 내부에 에러 정보가 있는지 확인
  const isError = result?.status === "error" || result?.ok === false;
  const statusMsg = isError ? `❌ Error: ${result?.message || "Unknown error"}` : "✅ Success";

  logger.info(`[AppSync] Command response from ${appId} (req:${requestId || "N/A"}): ${statusMsg}`);
  
  if (isError) {
    logger.debug(`[AppSync] Detailed error from ${appId}: ${JSON.stringify(result)}`);
  }
});
