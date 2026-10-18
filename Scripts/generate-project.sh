#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if [ -n "${XCODEGEN:-}" ]; then
  generator="$XCODEGEN"
elif command -v xcodegen >/dev/null 2>&1; then
  generator="$(command -v xcodegen)"
elif [ -x Scripts/.cache/XcodeGen/.build/aarch64-unknown-linux-gnu/release/xcodegen ] && [ "$(uname -s)" = Linux ]; then
  generator="$ROOT/Scripts/.cache/XcodeGen/.build/aarch64-unknown-linux-gnu/release/xcodegen"
else
  printf '%s\n' 'XcodeGen 2.44.1+ is needed to regenerate. On Mac: brew install xcodegen. The checked-in PhaseSystem.xcodeproj can be opened directly.' >&2
  exit 1
fi
mkdir -p logs
# Minimal Linux execution environments may omit USER; XcodeGen requires it.
export USER="${USER:-$(id -un)}"
"$generator" generate --spec project.yml 2>&1 | tee logs/project-generation.log
