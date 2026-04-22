/**
 * 도구 실행 컨텍스트 (AsyncLocalStorage 레일).
 * 오케스트레이터가 runWithExecutionContext 로 { agentId, appId, ttl } 를 깔면,
 * 도구 코드(app_control, schedule 등)는 getExecutionContext() 로 꺼내 쓴다.
 * 인자 전달로 모든 도구 시그니처를 오염시키지 않기 위한 통로.
 */

import { AsyncLocalStorage } from "async_hooks";

export type AgentExecutionContext = {
  agentId: string;
  appId?: string;
  /** 에이전트 간 호출 잔여 TTL. 도구(`control_app` 등)가 forward 시 decrement. */
  ttl?: number;
};

const executionContextStore = new AsyncLocalStorage<AgentExecutionContext>();

export function runWithExecutionContext<T>(
  context: AgentExecutionContext,
  callback: () => Promise<T>,
): Promise<T> {
  return executionContextStore.run(context, callback);
}

export function getExecutionContext(): AgentExecutionContext | undefined {
  return executionContextStore.getStore();
}
