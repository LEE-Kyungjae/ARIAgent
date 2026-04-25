export interface ExecuteAgentRequestInput {
  message: string;
  requestId: string;
  agentId?: string;
  persona?: string;
  avatarName?: string;
  platform?: string;
  appId?: string;
  socketAppId?: string;
  details?: Record<string, unknown>;
  waitForCompletion?: boolean;
  /** 스케줄러 trigger 발 호출이면 true → task 전용 system prompt 사용. */
  scheduledTask?: boolean;
  /** 요청을 보낸 소켓 uuid. 응답 라우팅 타겟. 없으면 task (스케줄러) 기원. */
  originUuid?: string;
  /** 에이전트 간 라우팅 raw 입력. `resolveInterAgentTarget` 가 해석한다. */
  from?: string;
  to?: string;
  /** 에이전트 간 잔여 TTL. `<= 0` 이면 reject (loop 방지). */
  ttl?: number;
}

/**
 * `ExecuteAgentRequestInput` 를 받아 기본값/트림까지 정규화한 실제 파라미터.
 * - persona: 없으면 ""
 * - avatarName: 없으면 "ARI"
 * - platform: 문자열이면 trim, 아니면 ""
 * - waitForCompletion: 명시 true 만 true
 */
export class ExecuteAgentRequestParams {
  message: string;
  requestId: string;
  agentId?: string;
  persona: string;
  avatarName: string;
  platform: string;
  appId?: string;
  socketAppId?: string;
  details?: Record<string, unknown>;
  waitForCompletion: boolean;
  scheduledTask: boolean;
  originUuid?: string;
  from?: string;
  to?: string;
  ttl?: number;

  constructor(data: ExecuteAgentRequestInput) {
    this.message = data.message;
    this.requestId = data.requestId;
    this.agentId = data.agentId;
    this.persona = data.persona || "";
    this.avatarName = data.avatarName || "ARI";
    this.platform =
      typeof data.platform === "string" ? data.platform.trim() : "";
    this.appId = data.appId;
    this.socketAppId = data.socketAppId;
    this.details = data.details;
    this.waitForCompletion = data.waitForCompletion === true;
    this.scheduledTask = data.scheduledTask === true;
    this.originUuid = data.originUuid;
    this.from = data.from;
    this.to = data.to;
    this.ttl = data.ttl;
  }
}
