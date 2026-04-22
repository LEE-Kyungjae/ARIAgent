import { PendingAgentResponse } from "../../../models/agent_response.js";
import { appendChatLog } from "../../../repositories/chat_log_repository.js";
import { pushApp } from "../../../protocol/app.js";
import { sendAgentRequest } from "../../../protocol/agent.js";
import { agentState } from "../provider/state.js";

/**
 * 사용 가능한 LLM 프로바이더가 없으면 에코 모드.
 * Setup agent (ARICloud) 도 availableProviders 에 들어가므로 보통 false.
 */
export function isEchoMode(): boolean {
  return agentState.availableProviders.length === 0;
}

export function buildEchoMessage(message: string): string {
  return `[에코 모드] "${message}"\n\n⚠️ Settings에서 하나 이상의 AI Provider API Key를 추가하세요.`;
}

/**
 * 에코 모드 응답을 발신 소켓으로 브로드캐스트하고 채팅 로그에 기록.
 * `submitAgentRequest` 의 에코 분기에서 사용.
 */
export function broadcastEchoResponse(
  message: string,
  agentId: string,
  pendingResponse: PendingAgentResponse,
): void {
  const responseText = buildEchoMessage(message);
  if (pendingResponse.originUuid) {
    sendAgentRequest({ uuid: pendingResponse.originUuid }, {
      message: pendingResponse.originalMessage,
      requestId: pendingResponse.requestId,
    });
  }
  appendChatLog(pendingResponse.appId, agentId, {
    type: "chat",
    isUser: true,
    message: pendingResponse.originalMessage,
    requestId: pendingResponse.requestId,
  });
  appendChatLog(pendingResponse.appId, agentId, {
    type: "chat",
    isUser: false,
    message: responseText,
    requestId: pendingResponse.requestId,
  });
  if (pendingResponse.originUuid) {
    pushApp({ uuid: pendingResponse.originUuid }, {
      ok: true,
      data: {
        response: responseText,
        requestId: pendingResponse.requestId,
        appId: pendingResponse.appId,
      },
    });
  }
}
