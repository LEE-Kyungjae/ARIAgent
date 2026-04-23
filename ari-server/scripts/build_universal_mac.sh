#!/bin/bash
# Build universal (arm64 + x64) ari-server standalone for macOS.
# Produces:
#   build/standalone/               — universal layout with lipo'd binary + both-arch native deps
#   build/runtime/                  — both playwright-darwin-arm64 and playwright-darwin-x64 tarballs
#
# Uses a pinned Node.js version for both arches so the SEA bundles stay ABI-compatible.
# Node 24 is needed for stable `node:sqlite` (used by repositories/sqlite_memory_repository.ts)
# and it's the latest major that runs under Rosetta 2 — Node 25+ fails with
# "unsupported thread-local, larger than 4GB".
set -euo pipefail

SERVER_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$SERVER_DIR"

NODE_VERSION="24.9.0"
NODE_CACHE_DIR="/tmp/ari-node-cache"
ARM64_NODE_DIR="$NODE_CACHE_DIR/node-v${NODE_VERSION}-darwin-arm64"
X64_NODE_DIR="$NODE_CACHE_DIR/node-v${NODE_VERSION}-darwin-x64"
ARM64_NODE_BIN="$ARM64_NODE_DIR/bin/node"
ARM64_NPM_BIN="$ARM64_NODE_DIR/bin/npm"
X64_NODE_BIN="$X64_NODE_DIR/bin/node"
X64_NPM_BIN="$X64_NODE_DIR/bin/npm"

ARM64_STAGING="/tmp/ari-universal-arm64"
X64_STAGING="/tmp/ari-universal-x64"

download_node() {
  local arch="$1"
  local target_dir="$NODE_CACHE_DIR/node-v${NODE_VERSION}-darwin-${arch}"
  if [ -x "$target_dir/bin/node" ]; then return; fi
  mkdir -p "$NODE_CACHE_DIR"
  local tarball="node-v${NODE_VERSION}-darwin-${arch}.tar.gz"
  curl -fsSL -o "$NODE_CACHE_DIR/$tarball" "https://nodejs.org/dist/v${NODE_VERSION}/${tarball}"
  tar -xzf "$NODE_CACHE_DIR/$tarball" -C "$NODE_CACHE_DIR"
  rm -f "$NODE_CACHE_DIR/$tarball"
}

echo "=== [universal] 1. Ensuring pinned Node v${NODE_VERSION} for both arches ==="
download_node "arm64"
download_node "x64"
"$ARM64_NODE_BIN" -e "if(process.arch!=='arm64'||process.version!=='v${NODE_VERSION}')process.exit(1)"
arch -x86_64 "$X64_NODE_BIN" -e "if(process.arch!=='x64'||process.version!=='v${NODE_VERSION}')process.exit(1)"

echo "=== [universal] 2. Install arm64 node_modules + build arm64 standalone ==="
rm -rf node_modules
PATH="$(dirname "$ARM64_NODE_BIN"):$PATH" "$ARM64_NPM_BIN" ci --no-audit --no-fund
PATH="$(dirname "$ARM64_NODE_BIN"):$PATH" "$ARM64_NODE_BIN" ./scripts/build.mjs standalone

rm -rf "$ARM64_STAGING"
mkdir -p "$ARM64_STAGING"
cp -R build/standalone "$ARM64_STAGING/standalone"
cp -R build/runtime "$ARM64_STAGING/runtime"

echo "=== [universal] 3. Install x64 node_modules + build x64 standalone ==="
rm -rf node_modules
PATH="$(dirname "$X64_NODE_BIN"):$PATH" \
  npm_config_arch=x64 npm_config_platform=darwin \
  arch -x86_64 "$X64_NPM_BIN" ci --no-audit --no-fund

PATH="$(dirname "$X64_NODE_BIN"):$PATH" \
  arch -x86_64 "$X64_NODE_BIN" ./scripts/build.mjs standalone

rm -rf "$X64_STAGING"
mkdir -p "$X64_STAGING"
cp -R build/standalone "$X64_STAGING/standalone"
cp -R build/runtime "$X64_STAGING/runtime"

echo "=== [universal] 4. Merge into universal layout ==="
rm -rf build/standalone build/runtime
mkdir -p build/standalone build/runtime

# Start from arm64 layout — non-native files are identical between arches.
cp -R "$ARM64_STAGING/standalone/." build/standalone/

# Overlay x64 sharp prebuild packages (sharp 0.34+ layout: @img/sharp-darwin-x64 + @img/sharp-libvips-darwin-x64).
for pkg in sharp-darwin-x64 sharp-libvips-darwin-x64; do
  SRC="$X64_STAGING/standalone/node_modules/@img/$pkg"
  if [ ! -d "$SRC" ]; then
    echo "[universal] ERROR: x64 @img/$pkg missing in staging" >&2
    exit 1
  fi
  mkdir -p "build/standalone/node_modules/@img"
  rm -rf "build/standalone/node_modules/@img/$pkg"
  cp -R "$SRC" "build/standalone/node_modules/@img/"
done

# Overlay x64 onnxruntime-node prebuild.
X64_ORT="$X64_STAGING/standalone/node_modules/onnxruntime-node/bin/napi-v3/darwin/x64"
if [ -d "$X64_ORT" ]; then
  cp -R "$X64_ORT" build/standalone/node_modules/onnxruntime-node/bin/napi-v3/darwin/
else
  echo "[universal] ERROR: x64 onnxruntime-node prebuild missing" >&2
  exit 1
fi

# lipo-create universal binary.
lipo -create \
  "$ARM64_STAGING/standalone/ari-server" \
  "$X64_STAGING/standalone/ari-server" \
  -output build/standalone/ari-server
chmod +x build/standalone/ari-server

# Copy both playwright runtime tarballs.
cp "$ARM64_STAGING/runtime/"*.tar.gz build/runtime/
cp "$X64_STAGING/runtime/"*.tar.gz build/runtime/

echo "=== [universal] Done ==="
file build/standalone/ari-server
lipo -info build/standalone/ari-server
ls build/runtime/
