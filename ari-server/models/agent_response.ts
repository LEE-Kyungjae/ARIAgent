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
  /** 에이전트 간 잔여 TTL. 도구가 forward 시 decrement. */
  ttl?: number;
}

export interface AgentPassResult {
  responseText: string;
  toolResults: AgentToolResultSummary[];
  finalAgent: Agent | null;
  lastError: Error | null;
  success: boolean;
}
