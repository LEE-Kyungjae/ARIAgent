import { AgentTool } from "@mariozechner/pi-agent-core";
import { logger } from "../infra/logger.js";

type AgentRuntimeSkill = {
  name: string;
  description: string;
  tools: string[];
  content: string;
  isApp?: boolean;
};

type AgentAvailableSkill = {
  name: string;
  description: string;
  isApp?: boolean;
};

type PromptSkillEntry = {
  name: string;
  description: string;
};

type PromptAppEntry = {
  name: string;
  description: string;
  isRunning: boolean;
};

export class AgentInfo {
  id: string;
  name: string;
  imagePath: string;
  description: string;
  persona: string;
  platform?: string;
  appId?: string;
  pinnedAppIds: string[];
  skillNames: string[];
  declare availableSkills: AgentAvailableSkill[];
  declare activeSkills: AgentRuntimeSkill[];
  declare runtimeTools: AgentTool[];

  constructor(data: any = {}) {
    this.initializeRuntimeState();
    this.id = data?.id || "default";
    this.name = data?.name || "ARI";
    this.imagePath = data?.imagePath || "";
    this.description = data?.description || "Default AI Assistant";
    this.persona = data?.persona || "";
    this.skillNames = AgentInfo.normalizeNames(data?.skillNames);
    this.pinnedAppIds = AgentInfo.normalizeNames(
      data?.pinnedAppIds ?? data?.appIds,
    );
    this.platform = data?.platform;
    this.appId = data?.appId;
  }

  get allowedSkillNames(): Set<string> {
    return new Set(this.skillNames);
  }

  get pinnedAppIdSet(): Set<string> {
    return new Set(this.pinnedAppIds);
  }

  get activeSkillToolNames(): Set<string> {
    const toolNames = new Set<string>();

    for (const skill of this.activeSkills) {
      for (const toolName of skill.tools) {
        const trimmedToolName = toolName.trim();
        if (trimmedToolName) {
          toolNames.add(trimmedToolName);
        }
      }
    }

    return toolNames;
  }

  get visibleSkills(): AgentAvailableSkill[] {
    return this.filterVisibleSkills(this.availableSkills);
  }

  /**
   * 프롬프트에 미리 소개할 핀된 앱 목록 (availableSkills 중 isApp && pinned).
   * 앱 호출 자체는 pinned 여부와 무관하게 항상 가능 — 이 getter 는 "힌트" 전용.
   */
  get pinnedApps(): AgentAvailableSkill[] {
    const pinned = this.pinnedAppIdSet;
    return this.availableSkills.filter(
      (skill) => skill.isApp && pinned.has(skill.name),
    );
  }

  get promptSkills(): PromptSkillEntry[] {
    return this.visibleSkills
      .filter((skill) => !skill.isApp)
      .map((skill) => ({
        name: skill.name,
        description: skill.description,
      }));
  }

  /**
   * 스킬(비앱) 화이트리스트 필터. 앱(isApp=true)은 이 필터에서 제외 — 앱은
   * 더 이상 에이전트가 "소유"하는 개념이 아니며, 호출 자체는 자유.
   * 프롬프트에 미리 소개할 핀 앱은 `pinnedApps` 게터를 사용한다.
   */
  filterVisibleSkills<T extends { name: string; isApp?: boolean }>(
    skills: T[],
  ): T[] {
    const allowedSkillNames = this.allowedSkillNames;

    return skills.filter((skill) => {
      if (skill.isApp) return false;
      return (
        allowedSkillNames.size === 0 || allowedSkillNames.has(skill.name)
      );
    });
  }

  pinApp(appId: string): boolean {
    if (!this.pinnedAppIds.includes(appId)) {
      this.pinnedAppIds.push(appId);
      return true;
    }
    return false;
  }

  unpinApp(appId: string): boolean {
    const idx = this.pinnedAppIds.indexOf(appId);
    if (idx !== -1) {
      this.pinnedAppIds.splice(idx, 1);
      return true;
    }
    return false;
  }

  toLoadedSkills<
    T extends {
      name: string;
      description: string;
      tools: string[];
      content: string;
    },
  >(
    skills: T[],
  ): Array<{
    name: string;
    description: string;
    tools: string[];
    content: string;
  }> {
    return skills.map((skill) => ({
      name: skill.name,
      description: skill.description,
      tools: skill.tools,
      content: skill.content,
    }));
  }

  toPromptApps(connectedAppIds: string[]): PromptAppEntry[] {
    const connectedAppIdSet = new Set(connectedAppIds);

    return this.pinnedApps.map((skill) => ({
      name: skill.name,
      description: skill.description,
      isRunning: connectedAppIdSet.has(skill.name),
    }));
  }

  resetTurnScopedSkills(): void {
    this.activeSkills = [];
    this.runtimeTools = [];
  }

  updateFrom(next: AgentInfo): void {
    this.id = next.id;
    this.name = next.name;
    this.imagePath = next.imagePath;
    this.description = next.description;
    this.persona = next.persona;
    this.platform = next.platform;
    this.appId = next.appId;
    this.skillNames = [...next.skillNames];
    this.pinnedAppIds = [...next.pinnedAppIds];
  }

  static fromJson(jsonStr: string | any): AgentInfo {
    const data = typeof jsonStr === "string" ? JSON.parse(jsonStr) : jsonStr;
    return new AgentInfo(data || {});
  }

  private initializeRuntimeState(): void {
    Object.defineProperty(this, "availableSkills", {
      value: [],
      writable: true,
      enumerable: false,
      configurable: true,
    });
    Object.defineProperty(this, "activeSkills", {
      value: [],
      writable: true,
      enumerable: false,
      configurable: true,
    });
    Object.defineProperty(this, "runtimeTools", {
      value: [],
      writable: true,
      enumerable: false,
      configurable: true,
    });
  }

  private static normalizeNames(values: unknown): string[] {
    if (!Array.isArray(values)) {
      return [];
    }

    return values
      .filter((value): value is string => typeof value === "string")
      .map((value) => value.trim())
      .filter((value) => value.length > 0);
  }
}

export class AgentsConfig {
  selected: string;
  agents: AgentInfo[];

  constructor(data: any = {}) {
    this.selected = data?.selected || "default";

    if (Array.isArray(data?.agents)) {
      this.agents = data.agents.map((a: any) => AgentInfo.fromJson(a));
    } else {
      this.agents = [];
    }
  }

  static fromJson(jsonStr: string | any): AgentsConfig {
    try {
      let data = typeof jsonStr === "string" ? JSON.parse(jsonStr) : jsonStr;

      // 마이그레이션 로직: 구형 Map 포맷이거나, 배열 포맷인 경우를 감지하여 변환
      if (Array.isArray(data)) {
        data = { selected: "default", agents: data };
      } else if (data && !data.agents) {
        const agentsArray = Object.values(data).filter((a) => typeof a === "object");
        data = { selected: "default", agents: agentsArray };
      }

      const config = new AgentsConfig(data);

      // 아무 에이전트 정보가 없으면 기본 ARI 하나 추가
      if (config.agents.length === 0) {
        config.agents.push(new AgentInfo());
      }

      return config;
    } catch (e) {
      logger.error("AgentsConfig parsing error:", e);
      const defaultConfig = new AgentsConfig();
      defaultConfig.agents.push(new AgentInfo());
      return defaultConfig;
    }
  }
}
