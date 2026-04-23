export interface TelegramChannelConfig {
  type: "telegram";
  enabled: boolean;
  botToken: string;
  agentId: string; // 소유 PM 에이전트 id. 파일명 키로도 사용.
}

export type ChannelConfig = TelegramChannelConfig;

export type ChannelType = "telegram";
