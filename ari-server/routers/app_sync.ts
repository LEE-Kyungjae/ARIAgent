import { router } from "../system/router.js";
import { UserSocketHandler } from "../system/ws.js";
import { logger } from "../infra/logger.js";
import { getCurrentState, getPluginsInfo } from "../services/agent/index.js";
import {
  commandApp,
  notifyAppNotice,
  notifyConnectedAppsChanged,
} from "../protocol/app.js";

/**
 * 이전 broadcast 시점의 연결 앱 목록. join/leave 차분을 계산해
 * /APP.NOTICE 로 채팅창에 "XXX 참여/퇴장" 메시지를 발행하는 데 쓰인다.
 */
let previousConnectedAppIds: Set<string> = new Set();

async function resolveAppTitle(appId: string): Promise<string> {
  if (appId === "ari") return "ARI";
  try {
    const { apps } = await getPluginsInfo();
    const match = apps.find((a: any) => a.name === appId);
    return (match as any)?.title || appId;
  } catch {
    return appId;
  }
}

/**
 * 실시간 연결된 앱 목록을 ari 소켓에 전송 (대시보드 갱신용).
 * 차분이 있는 경우 채팅창에 join/leave notice 도 발행.
 * ws.ts 의 소켓 close/error 및 아래 /APP.REGISTER 에서 호출된다.
 */
async function broadcastConnectedApps(): Promise<void> {
  const ids = UserSocketHandler.getConnectedAppIds();
  const current = new Set(ids);

  notifyConnectedAppsChanged(ids);

  // ari 본앱은 notice 발행 대상에서 제외 (자기 자신의 입장 알림은 불필요).
  const joined = [...current].filter(
    (id) => id !== "ari" && !previousConnectedAppIds.has(id),
  );
  const left = [...previousConnectedAppIds].filter(
    (id) => id !== "ari" && !current.has(id),
  );

  previousConnectedAppIds = current;

  for (const appId of joined) {
    const title = await resolveAppTitle(appId);
    notifyAppNotice({
      noticeId: `app-join-${appId}-${Date.now()}`,
      message: `${title}이(가) 대화방에 참여했습니다`,
    });
  }
  for (const appId of left) {
    const title = await resolveAppTitle(appId);
    notifyAppNotice({
      noticeId: `app-leave-${appId}-${Date.now()}`,
      message: `${title}이(가) 대화방에서 나갔습니다`,
    });
  }
}

UserSocketHandler.setOnAppConnectionChanged(() => {
  void broadcastConnectedApps();
});

router.on("/HEALTH", async (ctx) => {
  logger.info(`[Health] Check from ${ctx.uuid}`);
  const state = getCurrentState();
  const plugins = await getPluginsInfo();
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
  void broadcastConnectedApps();

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
