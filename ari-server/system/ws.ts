import { DateTime } from "luxon";
import WebSocket from "ws";
import { logger, log } from "../infra/logger.js";
import { router } from "./router.js";
import {
  abortAgentsForOrigin,
  clearAgentInstance,
} from "../services/agent/index.js";


// UserSocket 인터페이스를 확장하여 명시적으로 사용
export interface UserSocket extends WebSocket {
  isAlive: boolean;
  uuid: string;
  appId?: string; // 연결된 앱의 ID
  sysInfo: Record<string, any>;

  // 프로젝트 프로토콜 기반 전송으로 통합 (Polymorphic)
  send(cmd: string, data: any): void;
  send(data: any, cb?: (err?: Error) => void): void;
}

export namespace UserSocketHandler {
  let keepAlive: NodeJS.Timeout;
  const clients: UserSocket[] = [];
  let onAppConnectionChanged: (() => void) | null = null;

  /**
   * 앱 연결 상태 변경 시 호출될 콜백 등록 (app_sync.ts 에서 구독).
   * ws.ts 는 소켓 수명만 관리하고 브로드캐스트 로직은 소유하지 않는다.
   */
  export const setOnAppConnectionChanged = (cb: () => void): void => {
    onAppConnectionChanged = cb;
  };

  export const startKeepAlive = () => {
    const now = DateTime.local();
    log.report(`VER = ${process.env.VERSION}`);
    log.report(`SERVER MODE = ${process.env.MODE}`);
    log.report(
      `TIME = ${now.toFormat("yyyy-LL-dd HH:mm:ss.SSS")} (${Math.floor(now.toSeconds())})`,
    );
    log.report(
      `TIMEZONE = ${DateTime.now().setZone("Asia/Seoul").toFormat("yyyy-LL-dd HH:mm:ss.SSS ZZZ")}`,
    );

    const timeout = Number(process.env.KEEP_ALIVE_TIMEOUT) || 30000;
    keepAlive = setInterval(() => {
      clients.forEach((ws) => {
        if (!ws.isAlive) {
          ws.terminate();
          return;
        }
        ws.isAlive = false;
        ws.ping();
      });
    }, timeout);
  };

  export const onConnect = (socket: WebSocket, req: any) => {
    const ws = socket as UserSocket;

    const getUniqueID = (): string => {
      const s4 = () =>
        Math.floor((1 + Math.random()) * 0x10000)
          .toString(16)
          .substring(1);
      return `${s4()}${s4()}-${s4()}`;
    };

    const rawSend = ws.send.bind(ws);

    // Polyfill send to support (cmd, data) and (raw)
    ws.send = function (arg1: any, arg2?: any): void {
      if (typeof arg1 === "string" && arg2 !== undefined) {
        const result_str = `${arg1} ${JSON.stringify(arg2)}`;
        rawSend(result_str);
      } else {
        rawSend(arg1, arg2);
      }
    };

    ws.on("pong", () => {
      ws.isAlive = true;
    });

    ws.on("message", async (data: WebSocket.Data) => {
      const dataStr = data.toString();
      if (!dataStr.includes("/APP.REGISTER")) {
        logger.debug(`📥 Inbound: ${dataStr.substring(0, 100)}`);
      }
      ws.isAlive = true;
      try {
        await router.parse(ws, dataStr);
      } catch (err: any) {
        logger.error(`Error parsing message: ${err}`);
      }
    });

    ws.on("close", () => {
      logger.info(
        `closed uuid = ${ws.uuid}${ws.appId ? ` (${ws.appId})` : ""}`,
      );
      const index = clients.findIndex((item) => item.uuid === ws.uuid);
      if (index !== -1) {
        clients.splice(index, 1);
      }
      // 이 소켓이 발행한 진행 중 에이전트 턴 abort
      const aborted = abortAgentsForOrigin(ws.uuid);
      if (aborted.length > 0) {
        logger.info(
          `[ws.close] Aborted in-flight turns for uuid=${ws.uuid}: [${aborted.join(", ")}]`,
        );
      }
      // 써드파티 appId 세션은 소켓 수명과 동일. `ari` 는 PM 으로 서버 상주 — 정리하지 않는다.
      if (ws.appId && ws.appId !== "ari") {
        clearAgentInstance(ws.appId);
      }
      // Notify all clients if an app socket was closed
      if (ws.appId) {
        onAppConnectionChanged?.();
      }
    });

    ws.on("error", (err) => {
      logger.error(`error = ${ws.uuid}: ${err.message}`);
      if (ws.appId) {
        onAppConnectionChanged?.();
      }
    });

    ws.isAlive = true;
    ws.uuid = getUniqueID();
    clients.push(ws);

    const greetingParams = {
      ver: process.env.VERSION,
      dt: DateTime.local().toFormat("yyyy-LL-dd HH:mm"),
      mode: process.env.MODE,
    };
    ws.send("/GREETING", greetingParams);
    logger.info(`CLIENT connected = ${clients.length} (uuid: ${ws.uuid})`);
  };

  /**
   * 통합 전송 API. target 으로 소켓 (uuid) 또는 앱 (appId) 을 지정.
   * 1 앱 = 1 소켓 원칙이므로 appId 매칭은 사실상 유일 소켓이지만, 방어적으로 전 일치 소켓에 전송.
   * 대상이 없거나 닫혀 있으면 false.
   */
  export type SendTarget = { uuid: string } | { appId: string };

  export const send = (
    target: SendTarget,
    cmd: string,
    data: any,
  ): boolean => {
    if ("uuid" in target) {
      const t = clients.find((c) => c.uuid === target.uuid);
      if (!t || t.readyState !== WebSocket.OPEN) return false;
      t.send(cmd, data);
      return true;
    }
    let sent = false;
    clients.forEach((ws) => {
      if (ws.appId === target.appId && ws.readyState === WebSocket.OPEN) {
        ws.send(cmd, data);
        sent = true;
      }
    });
    return sent;
  };

  /**
   * originUuid 소켓에만 전송. 끊겼으면 drop (ari 폴백 없음 — sender-push 원칙).
   */
  export const sendToOrigin = (
    originUuid: string | undefined,
    cmd: string,
    data: any,
  ): boolean => {
    if (!originUuid) return false;
    return send({ uuid: originUuid }, cmd, data);
  };

  export const isAppConnected = (appId: string): boolean => {
    return clients.some(
      (c) =>
        (c.appId === appId ||
          c.appId?.replace("_", "") === appId.replace("_", "")) &&
        c.readyState === WebSocket.OPEN,
    );
  };

  /**
   * 해당 appId 로 등록된 첫 소켓 반환. 없으면 undefined.
   */
  export const findSocketByAppId = (appId: string): UserSocket | undefined => {
    return clients.find((c) => c.appId === appId);
  };

  /**
   * 소켓이 살아있는지 판정. OPEN 상태이면서 keep-alive 플래그가 유효해야 함.
   */
  export const isSocketAlive = (ws: UserSocket): boolean => {
    return ws.readyState === WebSocket.OPEN && ws.isAlive === true;
  };

  /**
   * 소켓을 강제로 내보내고 clients 배열에서 제거. 좀비 정리 시 사용.
   */
  export const dropSocket = (ws: UserSocket): void => {
    try {
      ws.terminate();
    } catch {
      // ignore
    }
    const index = clients.findIndex((item) => item.uuid === ws.uuid);
    if (index !== -1) {
      clients.splice(index, 1);
    }
  };

  export const getConnectedAppIds = (): string[] => {
    return clients
      .filter((c) => c && c.readyState === 1 && c.appId) // 1 === WebSocket.OPEN
      .map((c) => c.appId!);
  };
}
