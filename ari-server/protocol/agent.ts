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
