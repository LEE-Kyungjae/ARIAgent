import path from "path";
import { randomUUID } from "node:crypto";
import { DATA_DIR, fileExistsSync, readJsonSync, writeJsonSync, readTextSync } from "../infra/data.js";
import { Settings } from "../models/settings.js";
import { logger } from "../infra/logger.js";

const SETTINGS_FILE = path.join(DATA_DIR, "settings.json");

export function getSettingsText(defaultText: string): string {
  if (!fileExistsSync(SETTINGS_FILE)) {
    return defaultText;
  }
  return readTextSync(SETTINGS_FILE) || defaultText;
}

export function getSettings(defaultConfig: Settings): Settings {
  if (!fileExistsSync(SETTINGS_FILE)) {
    saveSettings(defaultConfig);
    return defaultConfig;
  }
  try {
    const configData = readJsonSync<any>(SETTINGS_FILE, null);
    if (!configData) return defaultConfig;

    // accountId 마이그레이션을 1회 실행하고, 변경되면 디스크에 저장.
    // 이후 부팅에서는 stable한 accountId를 유지.
    const migrated = migrateAccountIds(configData.PROVIDERS);
    if (migrated.changed) {
      configData.PROVIDERS = migrated.providers;
      saveSettings({ PROVIDERS: migrated.providers });
      logger.info(`[Settings] Migrated PROVIDERS accountId (${migrated.providers.length} entries)`);
    }

    return Settings.fromJson(configData);
  } catch (e) {
    logger.error(`설정 파일 파싱 오류, 디폴트값으로 초기화합니다:`, e);
    saveSettings(defaultConfig);
    return defaultConfig;
  }
}

// 레거시 PROVIDERS(→ accountId 누락 또는 중복)를 안전하게 정리
function migrateAccountIds(providers: any): { providers: any[]; changed: boolean } {
  if (!Array.isArray(providers)) return { providers: [], changed: false };

  let changed = false;
  const seenAccountIds = new Set<string>();
  const legacyProviderUsed = new Set<string>();

  const out = providers.map((p: any) => {
    const copy = { ...p };
    if (!copy.accountId) {
      // accountId 없음 → 첫 등장 provider는 provider id 유지(기존 OAuth 보존)
      // 두 번째부터는 uuid 할당
      if (!legacyProviderUsed.has(copy.provider)) {
        copy.accountId = copy.provider;
      } else {
        copy.accountId = randomUUID();
      }
      changed = true;
    }
    if (seenAccountIds.has(copy.accountId)) {
      copy.accountId = randomUUID();
      changed = true;
    }
    seenAccountIds.add(copy.accountId);
    legacyProviderUsed.add(copy.provider);
    return copy;
  });

  return { providers: out, changed };
}

export function saveSettings(settings: any): void {
  const existing = readJsonSync<any>(SETTINGS_FILE, {});
  const merged = { ...existing, ...settings };
  writeJsonSync(SETTINGS_FILE, merged);
}
