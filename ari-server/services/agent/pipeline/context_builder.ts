import { AgentMessage } from "@mariozechner/pi-agent-core";
import { AgentInfo } from "../../../models/agent.js";
import { AIProviders } from "../../../models/settings.js";
import { Prompt } from "../../../infra/prompt.js";
import { logger } from "../../../infra/logger.js";
import { readCoreMemory, searchRelevantMemories } from "../../memory/index.js";
import { getSettings } from "../../../repositories/setting_repository.js";
import { Settings } from "../../../models/settings.js";
import { getEmbeddingStatus } from "../../../infra/embedding.js";
import { ARI_CLOUD_PROVIDER } from "../provider/selector.js";
import { getCurrentTools } from "../plugin_cache.js";

export async function buildSystemPrompt(
  agentProfile: AgentInfo,
  providers?: AIProviders,
  userQuery?: string,
  isRoomContext?: boolean,
): Promise<string> {
  // setup 모드: 아직 프로바이더가 설정되지 않아 ARICloud 프록시를 사용 중인 경우
  // 일반 system_prompt 대신 setup 가이드 전용 프롬프트를 사용한다
  const isSetupMode =
    !!providers &&
    providers.availableProviders.length > 0 &&
    providers.availableProviders.every((p) => p.provider === ARI_CLOUD_PROVIDER);

  if (isSetupMode) {
    const setupPrompt = await Prompt.load("setup_system_prompt.hbs", {});
    return setupPrompt;
  }

  const agentId = agentProfile.id || "default";
  const settings = getSettings(new Settings());
  const useAdvancedMemory =
    settings.USE_ADVANCED_MEMORY && getEmbeddingStatus().status === "ready";

  // 고급 관계 지능이 활성화된 경우 벡터 검색으로 관련 메모리만 주입
  // 비활성화된 경우 기존 방식(전체 MEMORY.md + 어제/오늘 로그) 사용
  let coreMemory: string;

  if (useAdvancedMemory) {
    const query = userQuery || "recent context summary preferences rules";
    coreMemory = await searchRelevantMemories(query, agentId, 6);
  } else {
    coreMemory = readCoreMemory(agentId);
  }
  const avatarName = agentProfile.name.trim() || "ARI";
  const platform = agentProfile.platform?.trim() || process.platform;

  // 시스템 프롬프트에는 "핀된 앱"만 미리 소개한다. 호출 자체는
  // list_apps / control_app 을 통해 어떤 앱이든 가능.
  // (loadedSkills 본문은 매 턴 user context 에 inject — 시스템 프롬프트는 정적 유지.)
  const apps = agentProfile.pinnedApps.map((s) => ({
    name: s.name,
    description: s.description,
  }));

  // 메인툴 카탈로그 — 항상 사용 가능. 정적 (세션·턴 무관) 이라 시스템 프롬프트에 inject.
  const mainTools = getCurrentTools().map((t: any) => ({
    name: t.name,
    description: t.description,
  }));

  // 템플릿 라우팅. agentId 가 공용 `default` 여도 appId 가 도메인이면 도메인 역할로 실행.
  //   - appId 미지정 / "ari": PM 역할 (`pm_agent_prompt.hbs`)
  //   - 그 외 (SARI 등 도메인 앱): 도메인 전문가 역할 (`domain_agent_prompt.hbs`)
  const currentAppId = agentProfile.appId;
  const templateName =
    !currentAppId || currentAppId === "ari"
      ? "pm_agent_prompt.hbs"
      : "domain_agent_prompt.hbs";

  const systemPrompt = await Prompt.load(templateName, {
    avatarName,
    platform,
    appId: agentProfile.appId || undefined,
    persona: agentProfile.persona,
    coreMemory,
    skills: agentProfile.promptSkills,
    apps: apps.length > 0 ? apps : undefined,
    mainTools: mainTools.length > 0 ? mainTools : undefined,
    isRoomContext: !!isRoomContext,
  });

  // logger.debug(`[Agent] Built System Prompt:\n${systemPrompt}`);

  return systemPrompt;
}

export function pruneContext(
  messages: AgentMessage[],
): Promise<AgentMessage[]> {
  const maxMessages = 60; // 기본 메시지 유지 개수를 60개로 상향
  if (messages.length <= maxMessages) {
    return Promise.resolve(messages);
  }

  // 도구 호출(assistant)과 그 결과(tool)가 서로 끊어지지 않도록,
  // 항상 'user' 메시지부터 시작하는 안전한 자르기 지점을 찾습니다.
  const cutoff = messages.length - maxMessages;
  let startIndex = cutoff;
  while (startIndex < messages.length - 1) {
    if (messages[startIndex].role === "user") {
      break;
    }
    startIndex++;
  }

  // 윈도우 내에서 user 메시지를 찾지 못하면(매우 드문 경우),
  // 단순히 뒤에서부터 maxMessages 개만 취합니다.
  if (startIndex >= messages.length - 1) {
    startIndex = cutoff;
  }

  // 자르기 전 범위에서 read_skill 성공 tool_result 와 짝 assistant 메시지를 hoist.
  // (스킬 본문이 장기 세션에서도 살아있게 — 재읽기 방지.)
  const preserved: AgentMessage[] = [];
  const seenSkillNames = new Set<string>();
  for (let i = startIndex - 1; i >= 0; i--) {
    const msg = messages[i] as any;
    if (
      msg?.role !== "toolResult" ||
      msg?.toolName !== "read_skill" ||
      msg?.isError
    ) {
      continue;
    }
    const skillName = msg?.details?.name;
    if (typeof skillName !== "string" || seenSkillNames.has(skillName)) {
      continue;
    }
    seenSkillNames.add(skillName);
    const toolCallId = msg.toolCallId;
    for (let j = i - 1; j >= 0; j--) {
      const prev = messages[j] as any;
      if (prev?.role === "assistant" && Array.isArray(prev.content)) {
        const match = prev.content.some(
          (c: any) => c?.type === "toolCall" && c?.id === toolCallId,
        );
        if (match) {
          preserved.unshift(prev, msg);
          break;
        }
      }
    }
  }

  return Promise.resolve([...preserved, ...messages.slice(startIndex)]);
}
