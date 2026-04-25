import { Agent } from "@mariozechner/pi-agent-core";

export interface AgentToolResultSummary {
  toolName: string;
  details: any;
  isError: boolean;
}

export interface ChatWithAgentResult {
  responseText: string;
  aborted?: boolean;
}

export interface ExecuteAgentResult {
  status: "follow_up" | "broadcasted" | "cancelled";
  requestId: string;
  agentId: string;
  responseText?: string;
}

export interface PendingAgentResponse {
  requestId: string;
  agentId: string;
  originalMessage: string;
  appId?: string;
  /** 발신 에이전트 표시명 (avatarName). 클라 UI 라벨링용 (`[name] message`). */
  senderName?: string;
  /**
   * 이 요청을 발행한 원본 소켓의 uuid. 응답 라우팅의 기준.
   * task 등 소켓 외 기원이면 undefined — 이 경우 응답은 drop (sender-push 원칙).
   */
  originUuid?: string;
  /**
   * `/AGENT {from, to, …}` 라우팅 메타.
   * - `fromAppId`: 메시지 발신 앱 (ws.appId 또는 params.from)
   * - `toAppId`: 메시지 수신 에이전트 (params.to, 생략 시 fromAppId)
   * - `isInterAgent`: from ≠ to 이면 true → 응답 `/APP.PUSH` 에 from/to 메타 포함
   */
  fromAppId?: string;
  toAppId?: string;
  isInterAgent?: boolean;
  /**
   * 응답 라우팅 모드. intake 에서 한 번 결정 후 모든 송신 분기가 이를 따름.
   * - "user":          일반 사용자 요청 → originUuid 소켓에만 응답.
   * - "inter":         control_app 등 PM-도메인 직접 위임 → originUuid + 대상 앱 소켓.
   * - "ari-broadcast": ari 방 팬아웃 응답 → ari 소켓에만 표시 (대상 앱 1:1 채팅창은 깨끗).
   */
  dispatchMode?: "user" | "inter" | "ari-broadcast";
  /** 에이전트 간 잔여 TTL. 도구가 forward 시 decrement. */
  ttl?: number;
  /** 스케줄러 trigger 발 호출이면 true → task 전용 system prompt 사용. */
  scheduledTask?: boolean;
}

export interface AgentPassResult {
  responseText: string;
  toolResults: AgentToolResultSummary[];
  finalAgent: Agent | null;
  lastError: Error | null;
  success: boolean;
}
