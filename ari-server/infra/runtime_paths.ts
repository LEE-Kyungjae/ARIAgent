import fs from "fs";
import path from "path";
import os from "os";
let cachedIsSeaFn: (() => boolean) | null | undefined;

function uniquePaths(paths: string[]): string[] {
  return Array.from(new Set(paths.filter(Boolean).map((entry) => path.resolve(entry))));
}

function hasServerRuntimeMarkers(dirPath: string): boolean {
  return fs.existsSync(path.join(dirPath, "package.json")) ||
    fs.existsSync(path.join(dirPath, "template")) ||
    fs.existsSync(path.join(dirPath, "skills"));
}

function hasWorkspaceMarkers(dirPath: string): boolean {
  return fs.existsSync(path.join(dirPath, "README.md")) ||
    fs.existsSync(path.join(dirPath, "ari-app", "pubspec.yaml"));
}

function getEntryDir(): string {
  const entryFile = process.argv[1];
  if (entryFile) {
    return path.dirname(path.resolve(entryFile));
  }

  return path.dirname(process.execPath);
}

export function isBundledServer(): boolean {
  if (cachedIsSeaFn === undefined) {
    cachedIsSeaFn = null;
    try {
      // Older Node runtimes may not provide node:sea at all.
      const dynamicRequire = Function(
        "return typeof require !== 'undefined' ? require : null;",
      )() as ((specifier: string) => unknown) | null;

      const seaModule = dynamicRequire?.("node:sea") as
        | { isSea?: () => boolean }
        | undefined;
      if (typeof seaModule?.isSea === "function") {
        cachedIsSeaFn = seaModule.isSea;
      }
    } catch {
      cachedIsSeaFn = null;
    }
  }

  try {
    return cachedIsSeaFn?.() ?? false;
  } catch {
    return false;
  }
}

export function getServerRootDir(): string {
  const override = process.env.ARI_SERVER_ROOT;
  if (override && hasServerRuntimeMarkers(override)) {
    return path.resolve(override);
  }

  const execDir = path.dirname(process.execPath);
  const entryDir = getEntryDir();
  const candidates = isBundledServer()
    ? uniquePaths([
        execDir,
        path.join(execDir, "ari-server"),
      ])
    : uniquePaths([
        process.cwd(),
        path.join(process.cwd(), "ari-server"),
        entryDir,
        path.resolve(entryDir, ".."),
        path.resolve(entryDir, "..", ".."),
      ]);

  for (const candidate of candidates) {
    if (hasServerRuntimeMarkers(candidate)) {
      return candidate;
    }
  }

  return isBundledServer() ? execDir : path.resolve(entryDir, "..");
}

export function getWorkspaceRoot(): string {
  const override = process.env.ARI_WORKSPACE_ROOT;
  if (override && hasWorkspaceMarkers(override)) {
    return path.resolve(override);
  }

  const serverRoot = getServerRootDir();
  const candidates = uniquePaths([
    path.resolve(serverRoot, ".."),
    path.resolve(serverRoot, "..", ".."),
    process.cwd(),
    path.resolve(process.cwd(), ".."),
  ]);

  for (const candidate of candidates) {
    if (hasWorkspaceMarkers(candidate)) {
      return candidate;
    }
  }

  return path.resolve(serverRoot, "..");
}

export function resolveServerPath(...segments: string[]): string {
  return path.join(getServerRootDir(), ...segments);
}

export function getBundleRoots(): string[] {
  const candidates = uniquePaths([
    path.join(os.homedir(), ".ari-agent", "apps"),
    path.join(os.homedir(), ".ari-agent", "skills"),
    path.join(os.homedir(), ".ari-agent", "plugin"),
    getWorkspaceRoot(),
    path.join(getWorkspaceRoot(), "ari-app", "build", "macos", "Build", "Products", "Debug"),
    path.join(getWorkspaceRoot(), "ari-app", "build", "macos", "Build", "Products", "Release"),
  ]);

  return candidates.filter((candidate) => fs.existsSync(candidate));
}

export function getBundleRoot(): string {
  const roots = getBundleRoots();
  return roots.length > 0 ? roots[0] : path.join(os.homedir(), ".ari-agent", "skills");
}

function readDirEntries(dirPath: string): string[] {
  try {
    return fs.readdirSync(dirPath).filter((n) => !n.startsWith("."));
  } catch {
    return [];
  }
}

/**
 * 설치된 앱 번들(mac: .app / win: .exe)의 실행 파일 경로를 찾는다.
 * 번들 파일명이 무엇이든 상관없이 <root>/<appId>/ 아래를 스캔한다.
 */
export function findAppExecutable(appId: string): string | null {
  const bundleRoots = getBundleRoots();

  if (process.platform === "darwin") {
    for (const root of bundleRoots) {
      const appDir = path.join(root, appId);
      const bundles = readDirEntries(appDir).filter((n) => n.endsWith(".app"));

      for (const bundleName of bundles) {
        const macOsDir = path.join(appDir, bundleName, "Contents", "MacOS");
        const execs = readDirEntries(macOsDir);
        if (execs.length > 0) return path.join(macOsDir, execs[0]);
      }
    }
  } else if (process.platform === "win32") {
    for (const root of bundleRoots) {
      const appDir = path.join(root, appId);
      const exes = readDirEntries(appDir).filter((n) =>
        n.toLowerCase().endsWith(".exe"),
      );
      if (exes.length > 0) return path.join(appDir, exes[0]);
    }
  }

  return null;
}
