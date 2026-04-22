type AgentRuntimeStatus = "idle" | "working";

type AgentRuntimeState = {
  agentId: string;
  status: AgentRuntimeStatus;
  requestId?: string;
  updatedAt: string;
};

const runtimeStates = new Map<string, AgentRuntimeState>();

export function markAgentWorking(params: {
  agentId: string;
  requestId?: string;
}): AgentRuntimeState {
  const next: AgentRuntimeState = {
    agentId: params.agentId,
    status: "working",
    requestId: params.requestId,
    updatedAt: new Date().toISOString(),
  };
  runtimeStates.set(params.agentId, next);
  return next;
}

export function markAgentIdle(agentId: string): AgentRuntimeState {
  const next: AgentRuntimeState = {
    agentId,
    status: "idle",
    updatedAt: new Date().toISOString(),
  };
  runtimeStates.set(agentId, next);
  return next;
}
