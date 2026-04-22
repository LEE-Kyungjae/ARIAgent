import { sendAgentProgress } from "../../../protocol/agent.js";

/**
 * 진행 메시지 팬아웃 헬퍼. dispatchMode 에 따라 송신 대상이 결정된다.
 * - "user":          originUuid 에만.
 * - "inter":         originUuid + 대상 앱 소켓.
 * - "ari-broadcast": ari 소켓에만 (from/to 메타 포함 → 발신자 라벨 표시).
 *                    대상 앱 1:1 채팅창엔 표시 안 됨.
 */
export function createProgressFanout(opts: {
  requestId: string;
  agentId: string;
  appId?: string;
  originUuid?: string;
  toAppId?: string;
  fromAppId?: string;
  /** 발신 에이전트 표시명 (avatarName). 클라 progress UI 라벨링용. */
  senderName?: string;
  dispatchMode: "user" | "inter" | "ari-broadcast";
}): (progressMessage: string) => void {
  return (progressMessage: string) => {
    const baseData = {
      requestId: opts.requestId,
      agentId: opts.agentId,
      appId: opts.appId,
      message: progressMessage,
      senderName: opts.senderName,
    };

    if (opts.dispatchMode === "ari-broadcast") {
      sendAgentProgress(
        { appId: "ari" },
        {
          ok: true,
          data: { ...baseData, from: opts.toAppId, to: "ari" },
        },
      );
      return;
    }

    const payload = { ok: true as const, data: baseData };
    if (opts.originUuid) {
      sendAgentProgress({ uuid: opts.originUuid }, payload);
    }
    if (opts.dispatchMode === "inter" && opts.toAppId) {
      sendAgentProgress({ appId: opts.toAppId }, payload);
    }
  };
}
