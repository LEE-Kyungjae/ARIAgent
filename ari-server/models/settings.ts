import { randomUUID } from "node:crypto";
import { AgentTool } from "@mariozechner/pi-agent-core";
import { SkillDefinition } from "../skills/index.js";
import { logger } from "../infra/logger.js";
export type AuthType = "apikey" | "oauth";

export interface AvailablePlugins {
  tools: AgentTool[];
  skills: SkillDefinition[];
  apps: SkillDefinition[];
}

export class AIProviderConfig {
  provider: string;
  model: string;
  apiKey: string;
  authType: AuthType;
  accountId: string;

  constructor(data: any = {}) {
    this.provider = data?.provider || "";
    this.model = data?.model || "";
    this.apiKey = data?.apiKey || "";
    this.authType = data?.authType || "apikey";
    // accountId 누락 시 uuid 생성. 레거시 매핑(기존 단일 OAuth 유지)은
    // setting_repository.getSettings에서 1회 마이그레이션 후 디스크에 저장된다.
    this.accountId = data?.accountId || randomUUID();
  }
}

export class AIProviders {
  providers: AIProviderConfig[];
  availableProviders: AIProviderConfig[];
  currentModel: string;
  currentProvider: string;

  constructor(data: any = {}) {
    this.providers = this.dedupeAccountIds(
      this.normalizeProviders(data?.providers ?? data?.PROVIDERS),
    );
    this.availableProviders = this.normalizeProviders(
      data?.availableProviders,
    );

    const initialProvider =
      this.findProvider(
        data?.currentProvider ?? data?.PROVIDER,
        data?.currentModel ?? data?.OPENAI_MODEL,
      ) ??
      this.providers.find((provider) => !!provider.apiKey) ??
      this.providers[0];

    this.currentModel =
      data?.currentModel ?? initialProvider?.model ?? data?.OPENAI_MODEL ?? "gpt-5.3-codex";
    this.currentProvider =
      data?.currentProvider ?? initialProvider?.provider ?? data?.PROVIDER ?? "openai-codex";
  }

  setProviders(providers: AIProviderConfig[]): void {
    this.providers = this.dedupeAccountIds(this.normalizeProviders(providers));
    this.availableProviders = [];
    const current =
      this.activeConfig ??
      this.providers.find((provider) => !!provider.apiKey) ??
      this.providers[0];

    if (current) {
      this.currentProvider = current.provider;
      this.currentModel = current.model;
      return;
    }

    this.currentModel = "gpt-5.3-codex";
    this.currentProvider = "openai-codex";
  }

  setAvailableProviders(providers: AIProviderConfig[]): void {
    this.availableProviders = this.normalizeProviders(providers);
  }

  get activeConfig(): AIProviderConfig | null {
    return (
      this.findProvider(this.currentProvider, this.currentModel) ??
      this.findProvider(this.currentProvider) ??
      this.providers[0] ??
      null
    );
  }

  get startingAvailableProviderIndex(): number {
    const exactMatchIndex = this.availableProviders.findIndex(
      (provider) =>
        provider.provider === this.currentProvider &&
        provider.model === this.currentModel,
    );
    if (exactMatchIndex !== -1) {
      return exactMatchIndex;
    }

    const providerMatchIndex = this.availableProviders.findIndex(
      (provider) => provider.provider === this.currentProvider,
    );
    if (providerMatchIndex !== -1) {
      return providerMatchIndex;
    }

    return 0;
  }

  get currentApiKey(): string {
    return this.activeConfig?.apiKey ?? "";
  }

  set currentApiKey(apiKey: string) {
    const activeConfig = this.activeConfig;
    if (activeConfig) {
      activeConfig.apiKey = apiKey;
      return;
    }

    const fallbackProvider = new AIProviderConfig({
      provider: this.currentProvider,
      model: this.currentModel,
      apiKey,
      authType: "apikey",
    });
    this.providers = [fallbackProvider];
  }

  private normalizeProviders(providers: any): AIProviderConfig[] {
    if (!Array.isArray(providers)) {
      return [];
    }

    return providers.map((provider: any) =>
      provider instanceof AIProviderConfig
        ? provider
        : new AIProviderConfig(provider),
    );
  }

  // 같은 accountId를 가진 엔트리가 여럿이면 두 번째부터 새 uuid로 재발급.
  // 첫 엔트리는 기존 값을 유지 → 레거시 OAuth credentials 보존.
  private dedupeAccountIds(providers: AIProviderConfig[]): AIProviderConfig[] {
    const seen = new Set<string>();
    for (const p of providers) {
      if (!p.accountId || seen.has(p.accountId)) {
        p.accountId = randomUUID();
      }
      seen.add(p.accountId);
    }
    return providers;
  }

  private findProvider(providerName?: string, modelName?: string): AIProviderConfig | undefined {
    if (providerName && modelName) {
      const exactMatch = this.providers.find(
        (provider) =>
          provider.provider === providerName && provider.model === modelName,
      );
      if (exactMatch) {
        return exactMatch;
      }
    }

    if (providerName) {
      return this.providers.find((provider) => provider.provider === providerName);
    }

    if (modelName) {
      return this.providers.find((provider) => provider.model === modelName);
    }

    return undefined;
  }
}

export class Settings {
  PORT: number;
  IS_PINNED: boolean;
  AVATAR_SIZE: string;
  LANGUAGE: string;
  SHOW_TASK_MESSAGES: boolean;
  PROVIDERS: AIProviderConfig[];
  OPENAI_API_KEY: string;
  OPENAI_MODEL: string;
  PROVIDER: string;

  constructor(data: any = {}) {
    this.PORT = data?.PORT || 29277;
    this.IS_PINNED = data?.IS_PINNED !== undefined ? data.IS_PINNED : true;
    this.AVATAR_SIZE = data?.AVATAR_SIZE || "medium";
    this.LANGUAGE = data?.LANGUAGE || "ko";
    this.SHOW_TASK_MESSAGES =
      data?.SHOW_TASK_MESSAGES !== undefined ? data.SHOW_TASK_MESSAGES : true;

    if (Array.isArray(data?.PROVIDERS)) {
      this.PROVIDERS = data.PROVIDERS.map((p: any) => new AIProviderConfig(p));
    } else {
      this.PROVIDERS = [];
    }

    this.OPENAI_API_KEY = data?.OPENAI_API_KEY || "";
    this.OPENAI_MODEL = data?.OPENAI_MODEL || "gpt-5.3-codex";
    this.PROVIDER = data?.PROVIDER || "openai-codex";
  }

  static fromJson(jsonStr: string | any): Settings {
    try {
      const data = typeof jsonStr === "string" ? JSON.parse(jsonStr) : jsonStr;
      return new Settings(data);
    } catch (e) {
      logger.error("Settings parsing error:", e);
      return new Settings();
    }
  }
}
