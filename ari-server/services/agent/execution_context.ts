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
