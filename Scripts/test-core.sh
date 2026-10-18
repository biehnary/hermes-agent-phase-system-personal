#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if [ -n "${SWIFT:-}" ]; then
  compiler="$SWIFT"
elif command -v swift >/dev/null 2>&1; then
  compiler="$(command -v swift)"
elif [ -x .tools/swift-6.2.4-RELEASE-ubuntu24.04-aarch64/usr/bin/swift ]; then
  compiler="$ROOT/.tools/swift-6.2.4-RELEASE-ubuntu24.04-aarch64/usr/bin/swift"
else
  printf '%s\n' 'Swift 5.9+ is required. Use Xcode on Mac or an official Swift Linux toolchain.' >&2
  exit 1
fi
mkdir -p logs .tools/tmp .tools/cache
export TMPDIR="$ROOT/.tools/tmp" CLANG_MODULE_CACHE_PATH="$ROOT/.tools/cache/clang" SWIFTPM_MODULECACHE_OVERRIDE="$ROOT/.tools/cache/swift"
flags=()
if [ "$(uname -s)" = Linux ]; then
  flags=(--disable-sandbox --cache-path "$ROOT/.tools/cache/swiftpm" -Xlinker -z -Xlinker separate-code)
fi
"$compiler" --version
"$compiler" test ${flags[@]+"${flags[@]}"} "$@" 2>&1 | tee "logs/core-${PHASE_TEST_LABEL:-debug}.log"
