import fs from "fs";
import path from "path";
import { spawnSync } from "child_process";
import { fileURLToPath } from "url";
import { createRequire } from "module";

const require = createRequire(import.meta.url);
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, "..");
const distDir = path.join(rootDir, "dist");
const standaloneDir = path.join(rootDir, "build", "standalone");
const runtimeDir = path.join(rootDir, "build", "runtime");
const standaloneBinaryName = process.platform === "win32" ? "ari-server.exe" : "ari-server";
// Modules packaged into the on-demand playwright runtime tarball instead of
// shipped inside the standalone bundle. See ONDEMAND_RUNTIME_PLAN.md.
const playwrightRuntimeModules = ["playwright", "playwright-core"];
const playwrightVersion = JSON.parse(
  fs.readFileSync(path.join(rootDir, "node_modules", "playwright", "package.json"), "utf8"),
).version;
const nodeBinDir = path.dirname(process.execPath);
const standaloneExternalModules = [
  "playwright",
  "playwright-core",
  "chromium-bidi",
  "fsevents",
  "sharp",
  "onnxruntime-node",
  "@xenova/transformers",
];
// Transitive deps we do NOT want in the standalone bundle — they are pulled in
// by @xenova/transformers's package.json but never loaded at runtime on Node:
//   - onnxruntime-web: browser-only runtime (Node uses onnxruntime-node)
//   - onnx-proto / protobufjs: only needed by onnxruntime-web
//   - @types/*: TypeScript-only, zero runtime value
const excludedTransitiveModules = new Set([
  "onnxruntime-web",
  "onnx-proto",
  "protobufjs",
]);
const existingPath = process.env.PATH ?? process.env.Path ?? "";
const pathWithNode = process.platform === "win32"
  ? `${nodeBinDir};${existingPath}`
  : `${nodeBinDir}:${existingPath}`;

function runCommand(command, args, options = {}) {
  const result = spawnSync(command, args, {
    cwd: rootDir,
    stdio: "inherit",
    env: {
      ...process.env,
      PATH: pathWithNode,
      Path: pathWithNode,
    },
    ...options,
  });

  if (result.error) {
    console.error(`[build] Error running command ${command}:`, result.error);
    process.exit(1);
  }

  if (result.status !== 0) {
    console.error(`[build] Command ${command} failed with exit code ${result.status}`);
    process.exit(result.status ?? 1);
  }
}

function tryRunCommand(command, args, options = {}) {
  const result = spawnSync(command, args, {
    cwd: rootDir,
    stdio: "inherit",
    env: {
      ...process.env,
      PATH: pathWithNode,
      Path: pathWithNode,
    },
    ...options,
  });

  return result.status === 0;
}

function copyDirIfExists(sourceRelative, targetRoot) {
  const source = path.join(rootDir, sourceRelative);
  if (!fs.existsSync(source)) {
    return;
  }

  const target = path.join(targetRoot, sourceRelative);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.cpSync(source, target, { recursive: true });
}

function copySkills(targetRoot) {
  const skillsDir = path.join(rootDir, "skills");
  if (!fs.existsSync(skillsDir)) {
    return;
  }

  const targetDir = path.join(targetRoot, "skills");
  fs.mkdirSync(targetDir, { recursive: true });

  for (const entry of fs.readdirSync(skillsDir)) {
    fs.cpSync(path.join(skillsDir, entry), path.join(targetDir, entry), {
      recursive: true,
    });
  }
}

function copyNodeModuleIfExists(moduleName, targetRoot) {
  const source = path.join(rootDir, "node_modules", ...moduleName.split("/"));
  if (!fs.existsSync(source)) {
    return;
  }

  const target = path.join(targetRoot, "node_modules", ...moduleName.split("/"));
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.cpSync(source, target, { recursive: true });
}

function copyNodeModuleTree(moduleName, targetRoot, visited = new Set()) {
  if (visited.has(moduleName)) {
    return;
  }
  visited.add(moduleName);

  if (excludedTransitiveModules.has(moduleName)) {
    return;
  }

  const source = path.join(rootDir, "node_modules", ...moduleName.split("/"));
  if (!fs.existsSync(source)) {
    console.warn(`[build] Warning: node module not found for standalone copy: ${moduleName}`);
    return;
  }

  copyNodeModuleIfExists(moduleName, targetRoot);

  const packageJsonPath = path.join(source, "package.json");
  if (!fs.existsSync(packageJsonPath)) {
    return;
  }

  try {
    const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, "utf8"));
    const deps = {
      ...(packageJson.dependencies ?? {}),
      ...(packageJson.optionalDependencies ?? {}),
    };
    for (const dependency of Object.keys(deps)) {
      copyNodeModuleTree(dependency, targetRoot, visited);
    }
  } catch (error) {
    console.warn(
      `[build] Warning: failed to inspect dependencies for ${moduleName}: ${error instanceof Error ? error.message : String(error)}`,
    );
  }
}

function trimPlatformBloat(targetRoot) {
  // @xenova/transformers/dist is the browser UMD bundle + ORT WASM files.
  // Node resolves `main: ./src/transformers.js`, so dist/ is dead weight (~43MB).
  const xenovaDist = path.join(targetRoot, "node_modules", "@xenova", "transformers", "dist");
  if (fs.existsSync(xenovaDist)) {
    fs.rmSync(xenovaDist, { recursive: true, force: true });
    console.log("[build] Trimmed @xenova/transformers/dist (browser UMD + WASM, unused on Node)");
  }

  // onnxruntime-node ships prebuilds for 6 platforms (darwin/linux/win32 × arm64/x64).
  // Keep only the one matching this build's target platform/arch.
  const ortBin = path.join(targetRoot, "node_modules", "onnxruntime-node", "bin", "napi-v3");
  if (fs.existsSync(ortBin)) {
    const keepPlatform = process.platform;
    const keepArch = process.arch;
    for (const plat of fs.readdirSync(ortBin)) {
      const platDir = path.join(ortBin, plat);
      if (plat !== keepPlatform) {
        fs.rmSync(platDir, { recursive: true, force: true });
        continue;
      }
      for (const arch of fs.readdirSync(platDir)) {
        if (arch !== keepArch) {
          fs.rmSync(path.join(platDir, arch), { recursive: true, force: true });
        }
      }
    }
    console.log(`[build] Trimmed onnxruntime-node prebuilds (kept ${keepPlatform}/${keepArch} only)`);
  }
}

function cleanDir(targetDir) {
  console.log(`[build] Cleaning directory: ${targetDir}`);
  fs.rmSync(targetDir, { recursive: true, force: true });
  fs.mkdirSync(targetDir, { recursive: true });
}

function collectReachableModules(standaloneRoot, roots) {
  const standaloneModules = path.join(standaloneRoot, "node_modules");
  const collected = new Set();
  const queue = [...roots];

  while (queue.length > 0) {
    const moduleName = queue.shift();
    if (collected.has(moduleName)) continue;
    const modDir = path.join(standaloneModules, ...moduleName.split("/"));
    if (!fs.existsSync(modDir)) continue;
    collected.add(moduleName);

    const pkgJsonPath = path.join(modDir, "package.json");
    if (!fs.existsSync(pkgJsonPath)) continue;
    try {
      const pkg = JSON.parse(fs.readFileSync(pkgJsonPath, "utf8"));
      for (const dep of Object.keys(pkg.dependencies ?? {})) {
        if (!collected.has(dep)) queue.push(dep);
      }
    } catch {
      // ignore
    }
  }

  return collected;
}

function collectPlaywrightRuntimeModules(standaloneRoot) {
  // All modules reachable from playwright roots.
  const playwrightReachable = collectReachableModules(standaloneRoot, playwrightRuntimeModules);
  // Deps reachable from the remaining standalone roots — must NOT be moved.
  const nonPlaywrightRoots = standaloneExternalModules
    .filter((m) => !playwrightRuntimeModules.includes(m))
    .concat(["node-schedule"]);
  const keepInStandalone = collectReachableModules(standaloneRoot, nonPlaywrightRoots);

  return [...playwrightReachable].filter((m) => !keepInStandalone.has(m));
}

function packagePlaywrightRuntime(standaloneRoot, runtimeOutDir) {
  const standaloneModules = path.join(standaloneRoot, "node_modules");
  const stagingDir = path.join(
    runtimeOutDir,
    `playwright-${process.platform}-${process.arch}-v${playwrightVersion}`,
  );
  const stagingModules = path.join(stagingDir, "node_modules");

  const modulesToMove = collectPlaywrightRuntimeModules(standaloneRoot);
  let moved = 0;
  fs.mkdirSync(stagingModules, { recursive: true });
  for (const moduleName of modulesToMove) {
    const src = path.join(standaloneModules, ...moduleName.split("/"));
    if (!fs.existsSync(src)) continue;
    const dest = path.join(stagingModules, ...moduleName.split("/"));
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    fs.renameSync(src, dest);
    moved++;
  }

  if (moved === 0) {
    console.warn("[build] No playwright runtime modules found to package");
    fs.rmSync(stagingDir, { recursive: true, force: true });
    return;
  }

  const tarballName = `playwright-${process.platform}-${process.arch}-v${playwrightVersion}.tar.gz`;
  const tarballPath = path.join(runtimeOutDir, tarballName);
  fs.rmSync(tarballPath, { force: true });

  const tarCmd = process.platform === "win32" ? "tar.exe" : "tar";
  runCommand(tarCmd, ["-czf", tarballPath, "-C", stagingDir, "."]);
  fs.rmSync(stagingDir, { recursive: true, force: true });

  const sizeMb = (fs.statSync(tarballPath).size / (1024 * 1024)).toFixed(1);
  console.log(`[build] Packaged playwright runtime: ${tarballName} (${sizeMb} MB)`);
}

function buildTypeScript() {
  const tscCommand = process.platform === "win32"
    ? "cmd.exe"
    : path.join(rootDir, "node_modules", ".bin", "tsc");
  const tscArgs = process.platform === "win32"
    ? ["/c", path.join(rootDir, "node_modules", ".bin", "tsc.cmd")]
    : [];

  cleanDir(distDir);
  runCommand(tscCommand, tscArgs);
  fs.writeFileSync(
    path.join(distDir, "package.json"),
    JSON.stringify({
      type: "module",
      main: "index.js",
    }, null, 2),
  );
  copyDirIfExists("template", distDir);
  copySkills(distDir);
}

async function buildStandalone() {
  try {
    const { build: esbuild } = await import("esbuild");
    buildTypeScript();
    cleanDir(standaloneDir);

    const bundleFile = path.join(standaloneDir, "server.bundle.cjs");
    const launcherFile = path.join(standaloneDir, "sea-launcher.cjs");
    const seaConfigPath = path.join(standaloneDir, "sea-config.json");
    const seaBlobPath = path.join(standaloneDir, "sea-prep.blob");
    const outputBinaryPath = path.join(standaloneDir, standaloneBinaryName);

    await esbuild({
      entryPoints: [path.join(rootDir, "index.ts")],
      outfile: bundleFile,
      bundle: true,
      platform: "node",
      format: "cjs",
      target: "node22",
      sourcemap: false,
      logLevel: "info",
      external: standaloneExternalModules,
      // @xenova/transformers의 env.js가 import.meta.url로 경로를 계산하는데,
      // esbuild CJS 번들에서 import.meta가 빈 객체({})로 치환되어 url이 undefined가 됨.
      // banner로 번들 상단에 실제 URL 변수를 주입하고, define으로 해당 변수를 참조해
      // fileURLToPath(undefined) 에러를 방지.
      banner: {
        js: "var __bundle_import_meta_url = require('url').pathToFileURL(__filename).href;",
      },
      define: {
        "import.meta.url": "__bundle_import_meta_url",
        "__PLAYWRIGHT_RUNTIME_VERSION__": JSON.stringify(playwrightVersion),
      },
    });

    fs.writeFileSync(
      launcherFile,
      [
        'const { createRequire } = require("node:module");',
        'const path = require("node:path");',
        'const fs = require("node:fs");',
        'const binDir = path.dirname(process.execPath);',
        'const bundledBrowsers = path.join(binDir, "ms-playwright");',
        'if (fs.existsSync(bundledBrowsers)) {',
        '  process.env.PLAYWRIGHT_BROWSERS_PATH = bundledBrowsers;',
        '}',
        'const entryRequire = createRequire(path.join(binDir, "sea-launcher.cjs"));',
        'entryRequire("./server.bundle.cjs");',
        "",
      ].join("\n"),
    );

    fs.writeFileSync(seaConfigPath, JSON.stringify({
      main: launcherFile,
      output: seaBlobPath,
      disableExperimentalSEAWarning: true,
      useSnapshot: false,
      useCodeCache: false,
    }, null, 2));

    runCommand(process.execPath, ["--experimental-sea-config", seaConfigPath]);

    fs.copyFileSync(process.execPath, outputBinaryPath);

    if (process.platform === "darwin") {
      tryRunCommand("codesign", ["--remove-signature", outputBinaryPath], {
        stdio: "ignore",
      });
    }

    const postjectCli = require.resolve("postject/dist/cli.js");
    const postjectArgs = [
      postjectCli,
      outputBinaryPath,
      "NODE_SEA_BLOB",
      seaBlobPath,
      "--sentinel-fuse",
      "NODE_SEA_FUSE_fce680ab2cc467b6e072b8b5df1996b2",
    ];

    if (process.platform === "darwin") {
      postjectArgs.push("--macho-segment-name", "NODE_SEA");
    }

    runCommand(process.execPath, postjectArgs);
    if (process.platform === "darwin") {
      const didSign = tryRunCommand("codesign", ["--sign", "-", "--force", outputBinaryPath]);
      if (!didSign) {
        console.warn("[build] Warning: ad-hoc codesign failed for standalone macOS binary; continuing with unsigned runtime.");
      }
    }
    fs.chmodSync(outputBinaryPath, 0o755);

    copyDirIfExists("template", standaloneDir);
    copySkills(standaloneDir);
    for (const moduleName of standaloneExternalModules) {
      copyNodeModuleTree(moduleName, standaloneDir);
    }
    copyNodeModuleTree("node-schedule", standaloneDir);
    trimPlatformBloat(standaloneDir);

    cleanDir(runtimeDir);
    packagePlaywrightRuntime(standaloneDir, runtimeDir);

    fs.rmSync(launcherFile, { force: true });
    fs.rmSync(seaConfigPath, { force: true });
    fs.rmSync(seaBlobPath, { force: true });
  } catch (err) {
    console.error("[build] FATAL ERROR:", err);
    process.exit(1);
  }
}

const mode = process.argv[2] ?? "build";

if (mode === "standalone") {
  await buildStandalone();
} else {
  buildTypeScript();
}
