import { UserSocketHandler } from "../system/ws.js";

/**
 * /AGENT.* 아웃바운드 프로토콜.
 */

/**
 * 에이전트 실행 요청을 대상에게 알림 (사용자 메시지처럼 채팅창에 표시).
 */
export const sendAgentRequest = (
  target: UserSocketHandler.SendTarget,
  payload: Record<string, any>,
): void => {
  UserSocketHandler.send(target, "/AGENT.REQUEST", payload);
};

/**
 * 에이전트 진행 상태 ("생각 중", 중간 메시지 등) 를 대상에게 전달.
 */
export const sendAgentProgress = (
  target: UserSocketHandler.SendTarget,
  payload: { ok: true; data: Record<string, any> },
): void => {
  UserSocketHandler.send(target, "/AGENT.PROGRESS", payload);
};

/**
 * 이미 진행 중인 턴이 있어 follow-up 으로 큐잉됨을 알림.
 */
export const sendAgentFollowUp = (
  originUuid: string | undefined,
  payload: { ok: true; data: Record<string, any> },
): void => {
  UserSocketHandler.sendToOrigin(originUuid, "/AGENT.FOLLOW_UP", payload);
};

/**
 * 요청이 취소됐음을 알림 (UI 시스템 메시지 정리용).
 * 모든 abort 경로에서 통일해 발행된다.
 * - target 으로 SendTarget 받음 ({uuid} 또는 {appId}).
 *   ari 방 팬아웃 sub-agent 의 skip 등은 ari 소켓에 보내야 클라가 thinking 정리.
 */
export const sendAgentCancel = (
  target: UserSocketHandler.SendTarget,
  payload: Record<string, any>,
): void => {
  UserSocketHandler.send(target, "/AGENT.CANCEL", {
    ok: true,
    data: payload,
  });
};

/**
 * 자연어 지시를 대상 앱의 에이전트에게 포워딩 (SARI sender-push 원칙).
 */
export const forwardToAgent = (
  appId: string,
  payload: {
    from?: string;
    to: string;
    message: string;
    requestId: string;
    ttl?: number;
  },
): void => {
  UserSocketHandler.send({ appId }, "/AGENT.FORWARD", payload);
};
