import { UserSocketHandler } from "../../system/ws.js";

/**
 * 진행 메시지 팬아웃 헬퍼.
 * - 호출자 소켓 (`originUuid`) 에 항상 송신.
 * - 에이전트 간 호출이면 대상 앱 소켓에도 추가 송신 (해당 앱이 자기 세션의
 *   "생각 중" 진행도를 볼 수 있도록).
 */
export function createProgressFanout(opts: {
  requestId: string;
  agentId: string;
  appId?: string;
  originUuid?: string;
  isInterAgent: boolean;
  toAppId?: string;
}): (progressMessage: string) => void {
  return (progressMessage: string) => {
    const payload = {
      ok: true,
      data: {
        requestId: opts.requestId,
        agentId: opts.agentId,
        appId: opts.appId,
        message: progressMessage,
      },
    };
    UserSocketHandler.sendToOrigin(opts.originUuid, "/AGENT.PROGRESS", payload);
    if (opts.isInterAgent && opts.toAppId) {
      UserSocketHandler.send({ appId: opts.toAppId }, "/AGENT.PROGRESS", payload);
    }
  };
}
