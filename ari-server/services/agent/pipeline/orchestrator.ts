import { getAgentsConfig } from "../../../repositories/agent_repository.js";
import { AgentInfo, AgentsConfig } from "../../../models/agent.js";
import {
  ChatWithAgentResult,
  PendingAgentResponse,
} from "../../../models/agent_response.js";
import { logger } from "../../../infra/logger.js";
import { buildSystemPrompt, pruneContext } from "./context_builder.js";
import { extractFinalResponseText } from "./response_parser.js";
import { runWithExecutionContext } from "../execution_context.js";
import { getOrCreateSession } from "../session/session_manager.js";
import { loadAllSkills } from "../../../skills/index.js";
import { loadMainTools } from "../../../tools/index.js";
import { isRequestCancellationError } from "./inter_agent.js";
import { agentState } from "../provider/state.js";
import {
  getCurrentSkills,
  getCurrentTools,
  setCurrentSkills,
  setCurrentTools,
} from "../plugin_cache.js";
import {
  broadcastEchoResponse,
  buildEchoMessage,
  isEchoMode,
} from "./echo_mode.js";
import {
  applyFollowUp,
  clearStaleRequests,
  decideQueueAction,
} from "./request_queue.js";
import { dropPendingResponse } from "../control.js";

function getSessionForAgent(agentProfile: AgentInfo) {
  return getOrCreateSession(
    agentProfile,
    agentState,
    pruneContext,
    (provider, error) => {
      logger.warn(
        `[Agent] Invalid model config (${provider.provider}, ${provider.model}): `,
        error,
      );
    },
  );
}

async function chatWithAgent(
  message: string,
  agentProfile: AgentInfo = new AgentInfo(),
  onProgress?: (message: string) => void,
  pendingResponse?: PendingAgentResponse,
): Promise<ChatWithAgentResult> {
  const currentAgentId =
    agentProfile.id ||
    getAgentsConfig(new AgentsConfig()).selected ||
    "default";
  const currentAgentProfile = new AgentInfo({
    ...agentProfile,
    id: currentAgentId,
  });

  if (isEchoMode()) {
    return { responseText: buildEchoMessage(message) };
  }

  if (getCurrentTools().length === 0) {
    setCurrentTools(await loadMainTools());
  }

  setCurrentSkills(await loadAllSkills());

  const session = getSessionForAgent(currentAgentProfile);
  session.agentInfo.availableSkills = getCurrentSkills();
  session.ensureLifecycleAttached();
  if (pendingResponse) {
    session.enqueueRequest(pendingResponse);
  }

  const systemPrompt = await buildSystemPrompt(session.agentInfo, agentState, message);
  const result = await runWithExecutionContext(
    {
      agentId: currentAgentId,
      appId: currentAgentProfile.appId,
      ttl: pendingResponse?.ttl,
    },
    () =>
      session.runInference(
        message,
        systemPrompt,
        agentState,
        onProgress,
      ),
  );

  if (!result.success) {
    if (result.aborted) {
      return { responseText: "", aborted: true };
    }

    if (result.lastError) {
      return {
        responseText: `❌ 모든 프로바이더에서 오류가 발생했습니다: ${result.lastError.message}`,
      };
    }

    return {
      responseText: "❌ 사용 가능한 프로바이더가 없습니다.",
    };
  }

  return {
    responseText:
      result.responseText ||
      extractFinalResponseText(session.agent) ||
      "처리 중 오류가 발생했습니다.",
  };
}

export async function submitAgentRequest(
  message: string,
  agentProfile: AgentInfo,
  onProgress: ((message: string) => void) | undefined,
  pendingResponse: PendingAgentResponse,
): Promise<{ status: "follow_up" | "broadcasted" | "cancelled" }> {
  const agentId = pendingResponse.agentId || agentProfile.id || "default";
  const currentAgentProfile = new AgentInfo({
    ...agentProfile,
    id: agentId,
  });

  if (isEchoMode()) {
    broadcastEchoResponse(message, agentId, pendingResponse);
    return { status: "broadcasted" };
  }

  const session = getSessionForAgent(currentAgentProfile);
  session.ensureLifecycleAttached();
  session.enqueueRequest(pendingResponse);

  if (decideQueueAction(session) === "follow_up") {
    applyFollowUp(session, message, agentId, pendingResponse);
    return { status: "follow_up" };
  }

  clearStaleRequests(session, pendingResponse.requestId, agentId);
  session.beginNextRequest();

  const result = await chatWithAgent(message, agentProfile, onProgress, pendingResponse);
  if (result.aborted) {
    session.removeRequest(pendingResponse.requestId);
    return { status: "cancelled" };
  }
  return { status: "broadcasted" };
}

export async function submitAgentRequestAndWait(
  message: string,
  agentProfile: AgentInfo,
  onProgress: ((message: string) => void) | undefined,
  pendingResponse: PendingAgentResponse,
): Promise<{
  status: "follow_up" | "broadcasted" | "cancelled";
  responseText?: string;
}> {
  const agentId = pendingResponse.agentId || agentProfile.id || "default";
  const currentAgentProfile = new AgentInfo({
    ...agentProfile,
    id: agentId,
  });

  if (isEchoMode()) {
    const result = await submitAgentRequest(
      message,
      currentAgentProfile,
      onProgress,
      pendingResponse,
    );
    return {
      status: result.status,
      responseText: buildEchoMessage(message),
    };
  }

  const session = getSessionForAgent(currentAgentProfile);
  session.ensureLifecycleAttached();
  const completion = session
    .waitForRequestCompletion(pendingResponse.requestId)
    .then((responseText) => ({ status: "completed" as const, responseText }))
    .catch((error) => {
      if (isRequestCancellationError(error)) {
        return { status: "cancelled" as const };
      }
      throw error;
    });

  try {
    const result = await submitAgentRequest(
      message,
      currentAgentProfile,
      onProgress,
      pendingResponse,
    );

    if (result.status === "cancelled") {
      return { status: "cancelled" };
    }

    const completionResult = await completion;
    if (completionResult.status === "cancelled") {
      return { status: "cancelled" };
    }

    return {
      status: result.status,
      responseText: completionResult.responseText,
    };
  } catch (error) {
    if (isRequestCancellationError(error)) {
      return { status: "cancelled" };
    }
    dropPendingResponse(agentId, pendingResponse.requestId);
    throw error;
  }
}
