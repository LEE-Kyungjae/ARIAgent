import fs from "fs";
import path from "path";
import { readDirSyncSafe, DATA_DIR, ensureDirSync } from "../infra/data.js";
import { getBundleRoots, resolveServerPath } from "../infra/runtime_paths.js";

export interface SkillDefinition {
  name: string;
  title: string;
  description: string;
  tools: string[];
  content: string;
  filePath: string;
  isCustom?: boolean;
  isApp?: boolean;
  icon?: string;
  iconPath?: string;
}

export type AppDefinition = SkillDefinition;

interface SkillFrontmatter {
  name?: string;
  description?: string;
  "allowed-tools"?: string;
  "user-invocable"?: string;
  "disable-model-invocation"?: string;
  icon?: string;
  [key: string]: string | undefined;
}

function parseFrontmatter(raw: string): { frontmatter: SkillFrontmatter; body: string } {
  const trimmed = raw.trim();
  if (!trimmed.startsWith("---")) {
    return { frontmatter: {}, body: raw };
  }

  const endIndex = trimmed.indexOf("---", 3);
  if (endIndex === -1) {
    return { frontmatter: {}, body: raw };
  }

  const fmBlock = trimmed.slice(3, endIndex).trim();
  const body = trimmed.slice(endIndex + 3).trim();
  const frontmatter: SkillFrontmatter = {};

  for (const line of fmBlock.split(/\r?\n/)) {
    const colonIndex = line.indexOf(":");
    if (colonIndex === -1) continue;
    const key = line.slice(0, colonIndex).trim();
    const value = line.slice(colonIndex + 1).trim();
    if (key) {
      frontmatter[key] = value;
    }
  }

  return { frontmatter, body };
}

function parseToolsFromFrontmatter(fm: SkillFrontmatter): string[] {
  const raw = fm["allowed-tools"];
  if (!raw) return [];
  return raw
    .split(/[\s,]+/)
    .map((t) => t.trim())
    .filter((t) => t.length > 0);
}

function parseDescriptionFallback(body: string): string {
  const lines = body.split(/\r?\n/);
  for (const rawLine of lines) {
    const line = rawLine.trim();
    if (!line) continue;
    if (line.startsWith("#")) continue;
    if (line.startsWith("```")) continue;
    return line;
  }
  return "추가 지침을 담고 있는 스킬입니다.";
}

function loadSkillsFromDir(dirPath: string): SkillDefinition[] {
  const skills: SkillDefinition[] = [];
  if (!fs.existsSync(dirPath)) return skills;

  const entries = readDirSyncSafe(dirPath);
  for (const entry of entries) {
    const skillDir = path.join(dirPath, entry);
    let stat: fs.Stats;
    try {
      stat = fs.statSync(skillDir);
    } catch {
      continue;
    }

    if (!stat.isDirectory()) continue;

    const skillFilePath = path.join(skillDir, "SKILL.md");
    if (!fs.existsSync(skillFilePath)) continue;

    const raw = fs.readFileSync(skillFilePath, "utf8").trim();
    if (!raw) continue;

    const { frontmatter: fm, body } = parseFrontmatter(raw);

    const iconFilePath = path.join(skillDir, "icon.png");
    const appInfoPath = path.join(skillDir, "app_info.json");
    let appInfo: { name?: string; description?: string } | null = null;
    if (fs.existsSync(appInfoPath)) {
      try {
        appInfo = JSON.parse(fs.readFileSync(appInfoPath, "utf8"));
      } catch {
        appInfo = null;
      }
    }
    skills.push({
      name: fm.name || entry,
      title: appInfo?.name ?? fm.name ?? entry,
      description: fm.description || appInfo?.description || parseDescriptionFallback(body),
      tools: parseToolsFromFrontmatter(fm),
      icon: fm.icon,
      iconPath: fs.existsSync(iconFilePath) ? iconFilePath : undefined,
      content: body,
      filePath: skillFilePath,
      isApp: fs.existsSync(path.join(skillDir, "app.app")) || fs.existsSync(appInfoPath),
    });
  }
  return skills;
}

export async function loadAllSkills(): Promise<SkillDefinition[]> {
  const skillMap = new Map<string, SkillDefinition>();

  // 1. 기본 제공 스킬
  const builtInDirs = [
    resolveServerPath("skills"),
    path.join(process.cwd(), "skills"),
    path.join(process.cwd(), "ari-server", "skills"),
  ];

  for (const dir of builtInDirs) {
    for (const skill of loadSkillsFromDir(dir)) {
      if (skill.isApp) continue;
      skillMap.set(skill.name, { ...skill, isCustom: false });
    }
  }

  // 2. 커스텀 스킬 (~/.ari-agent/skills) — 앱 제외
  const userSkillsDir = path.join(DATA_DIR, "skills");
  ensureDirSync(userSkillsDir);
  for (const skill of loadSkillsFromDir(userSkillsDir)) {
    if (skill.isApp) continue;
    skillMap.set(skill.name, { ...skill, isCustom: true });
  }

  const result = Array.from(skillMap.values());
  result.sort((a, b) => a.name.localeCompare(b.name));
  return result;
}

export async function loadAllApps(): Promise<AppDefinition[]> {
  const appMap = new Map<string, AppDefinition>();

  // 1. 번들 루트 (설치된 .app 패키지 등)
  for (const dir of getBundleRoots()) {
    for (const skill of loadSkillsFromDir(dir)) {
      if (!skill.isApp) continue;
      appMap.set(skill.name, { ...skill, isCustom: true });
    }
  }

  // 2. 레거시: ~/.ari-agent/skills 에 isApp으로 설치된 항목
  const legacySkillsDir = path.join(DATA_DIR, "skills");
  for (const skill of loadSkillsFromDir(legacySkillsDir)) {
    if (!skill.isApp) continue;
    appMap.set(skill.name, { ...skill, isCustom: true });
  }

  // 3. 사용자 앱 (~/.ari-agent/apps) — 여기가 새 기본 위치
  const userAppsDir = path.join(DATA_DIR, "apps");
  ensureDirSync(userAppsDir);
  for (const skill of loadSkillsFromDir(userAppsDir)) {
    appMap.set(skill.name, { ...skill, isCustom: true, isApp: true });
  }

  const result = Array.from(appMap.values());
  result.sort((a, b) => a.name.localeCompare(b.name));
  return result;
}

/** 프롬프트용: 스킬 + 앱을 합쳐서 반환. */
export async function loadSkillsForPrompt(): Promise<SkillDefinition[]> {
  const [skills, apps] = await Promise.all([loadAllSkills(), loadAllApps()]);
  return [...skills, ...apps];
}
