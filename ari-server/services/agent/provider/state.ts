import { AIProviders } from "../../../models/settings.js";

/**
 * 프로세스-전역 AI 프로바이더 상태.
 * `initAgent` 가 설정/OAuth 상태를 보고 `availableProviders` 를 채우며,
 * 세션/오케스트레이터/컨텍스트 빌더가 런타임 중 동일 인스턴스를 공유해 읽는다.
 */
export const agentState = new AIProviders();

export function getCurrentState(): AIProviders {
  return agentState;
}
