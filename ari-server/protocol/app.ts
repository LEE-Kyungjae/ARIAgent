import { router } from "../system/router.js";
import { UserSocketHandler } from "../system/ws.js";
import { logger } from "../infra/logger.js";

/**
 * /APP.* 아웃바운드 프로토콜.
 * ws.send 직접 호출은 이 파일에서만 이루어진다.
 */

/**
 * 특정 앱에 /APP.COMMAND 를 발행하고 /APP.COMMAND_RESPONSE 를 기다리는 아웃바운드 RPC.
 */
export const commandApp = async (
  appId: string,
  command: string,
  params: any = {},
  timeoutMs = 10000,
): Promise<any> => {
  const requestId = Math.random().toString(36).substring(7);

  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      router.off(`/APP.COMMAND_RESPONSE:${requestId}`);
      reject(
        new Error(
          `Command '${command}' to '${appId}' timed out (${timeoutMs}ms)`,
        ),
      );
    }, timeoutMs);

    router.once(`/APP.COMMAND_RESPONSE:${requestId}`, (_ctx, data) => {
      clearTimeout(timeout);
      resolve(data.result);
    });

    const sent = UserSocketHandler.send(
      { appId },
      "/APP.COMMAND",
      { appId, command, requestId, params },
    );
    if (!sent) {
      clearTimeout(timeout);
      router.off(`/APP.COMMAND_RESPONSE:${requestId}`);
      reject(new Error(`App '${appId}' is not connected.`));
      return;
    }
    logger.debug(
      `[Protocol/App] Sent Command to ${appId}: ${command} (req:${requestId})`,
    );
  });
};

/**
 * ari 대시보드에 연결된 앱 목록 변동 알림.
 */
export const notifyConnectedAppsChanged = (connectedIds: string[]): void => {
  UserSocketHandler.send(
    { appId: "ari" },
    "/CONNECTED_APPS_CHANGED",
    { connectedIds },
  );
};

/**
 * ari 대시보드에 설치된 앱 목록 변동 알림.
 */
export const notifyInstalledAppsChanged = (appId: string): void => {
  UserSocketHandler.send(
    { appId: "ari" },
    "/INSTALLED_APPS_CHANGED",
    { appId },
  );
};

/**
 * ari 에게 태스크/작업 관련 notice 전달 (채팅창 상단 배너 등).
 * agentId 를 생략하면 모든 에이전트 채팅에 노출된다.
 */
export const notifyAppNotice = (payload: {
  noticeId: string;
  agentId?: string;
  message: string;
}): void => {
  UserSocketHandler.send({ appId: "ari" }, "/APP.NOTICE", payload);
};

/**
 * 에이전트 응답 등을 대상 소켓(uuid) 또는 특정 앱에 /APP.PUSH 로 전달.
 */
export const pushApp = (
  target: UserSocketHandler.SendTarget,
  payload: { ok: true; data: Record<string, any> },
): void => {
  UserSocketHandler.send(target, "/APP.PUSH", payload);
};

/**
 * 에이전트 에러 등을 /APP.ERROR 로 전달.
 */
export const errorApp = (
  target: UserSocketHandler.SendTarget,
  payload: { ok: false; data: Record<string, any> },
): void => {
  UserSocketHandler.send(target, "/APP.ERROR", payload);
};
