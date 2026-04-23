import path from "path";
import {
  DATA_DIR,
  fileExistsSync,
  readDirSyncSafe,
  readJsonSync,
  writeJsonSync,
} from "../infra/data.js";
import { TelegramChannelConfig } from "../models/channel.js";

const TELEGRAM_DIR = path.join(DATA_DIR, "channels", "telegram");

function telegramFilePath(agentId: string): string {
  return path.join(TELEGRAM_DIR, `${agentId}.json`);
}

export function getTelegramConfig(agentId: string): TelegramChannelConfig {
  const filePath = telegramFilePath(agentId);
  if (!fileExistsSync(filePath)) {
    return defaultTelegramConfig(agentId);
  }
  const data = readJsonSync<TelegramChannelConfig>(filePath);
  return data ? { ...data, agentId } : defaultTelegramConfig(agentId);
}

export function saveTelegramConfig(config: TelegramChannelConfig): void {
  writeJsonSync(telegramFilePath(config.agentId), config);
}

export function listTelegramConfigs(): TelegramChannelConfig[] {
  return readDirSyncSafe(TELEGRAM_DIR)
    .filter((name) => name.endsWith(".json"))
    .map((name) => getTelegramConfig(name.slice(0, -".json".length)));
}

function defaultTelegramConfig(agentId: string): TelegramChannelConfig {
  return {
    type: "telegram",
    enabled: false,
    botToken: "",
    agentId,
  };
}
