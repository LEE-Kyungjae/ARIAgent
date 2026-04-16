import path from "path";
import { DATA_DIR, fileExistsSync, readJsonSync, writeJsonSync } from "../infra/data.js";
import { logger } from "../infra/logger.js";

export type OAuthProvider = "openai-codex" | "anthropic" | "github-copilot" | "google-gemini-cli" | "google-antigravity";

export interface OAuthCredentials {
  type: "oauth";
  [key: string]: any;
}

// accountId 단위로 저장한다. 같은 provider라도 accountId가 다르면 별도 계정.
export interface OAuthEntry {
  provider: OAuthProvider;
  credentials: OAuthCredentials;
}

export type OAuthEntryMap = Record<string, OAuthEntry>;

const OAUTH_FILE = path.join(DATA_DIR, "oauth.json");

const KNOWN_PROVIDERS: readonly OAuthProvider[] = [
  "openai-codex",
  "anthropic",
  "github-copilot",
  "google-gemini-cli",
  "google-antigravity",
];

// 레거시 형태({ [provider]: credentials }) 감지
function isLegacyShape(raw: any): boolean {
  if (!raw || typeof raw !== "object") return false;
  for (const [key, value] of Object.entries(raw)) {
    if (!value || typeof value !== "object") continue;
    // 새 형식이면 value에 provider 필드가 있다
    if ((value as any).provider && (value as any).credentials) return false;
    // key가 알려진 provider면 레거시로 간주
    if (KNOWN_PROVIDERS.includes(key as OAuthProvider)) return true;
  }
  return false;
}

function migrateLegacy(raw: any): OAuthEntryMap {
  const out: OAuthEntryMap = {};
  for (const [key, value] of Object.entries(raw || {})) {
    if (!value || typeof value !== "object") continue;
    if (!KNOWN_PROVIDERS.includes(key as OAuthProvider)) continue;
    // 레거시: accountId = providerId, 기존 단일 계정 유지
    out[key] = {
      provider: key as OAuthProvider,
      credentials: value as OAuthCredentials,
    };
  }
  return out;
}

export function loadOAuthEntries(): OAuthEntryMap {
  if (!fileExistsSync(OAUTH_FILE)) {
    return {};
  }
  try {
    const raw = readJsonSync<any>(OAUTH_FILE) ?? {};
    if (isLegacyShape(raw)) {
      const migrated = migrateLegacy(raw);
      logger.info(`[OAuthRepo] Migrated legacy oauth.json (${Object.keys(migrated).length} entries)`);
      writeJsonSync(OAUTH_FILE, migrated);
      return migrated;
    }
    return raw as OAuthEntryMap;
  } catch (e) {
    logger.error("[OAuthRepo] Failed to load oauth.json:", e);
    return {};
  }
}

export function saveOAuthEntries(map: OAuthEntryMap): void {
  try {
    writeJsonSync(OAUTH_FILE, map);
    logger.info("[OAuthRepo] OAuth entries saved.");
  } catch (e) {
    logger.error("[OAuthRepo] Failed to save oauth.json:", e);
  }
}

export function getEntry(accountId: string): OAuthEntry | null {
  const map = loadOAuthEntries();
  return map[accountId] ?? null;
}

export function setEntry(accountId: string, entry: OAuthEntry): void {
  const map = loadOAuthEntries();
  map[accountId] = entry;
  saveOAuthEntries(map);
}

export function deleteEntry(accountId: string): void {
  const map = loadOAuthEntries();
  delete map[accountId];
  saveOAuthEntries(map);
}

export function listEntries(): Array<{ accountId: string } & OAuthEntry> {
  const map = loadOAuthEntries();
  return Object.entries(map).map(([accountId, entry]) => ({ accountId, ...entry }));
}
