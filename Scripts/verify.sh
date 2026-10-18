#!/bin/bash
# Available checks only. This never pretends that parsing is an Apple SDK build.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if [ "${PHASE_REGENERATE_PROJECT:-0}" = 1 ] || [ ! -f PhaseSystem.xcodeproj/project.pbxproj ]; then
  bash Scripts/generate-project.sh
else
  printf '%s\n' 'Preserving existing Xcode project. Set PHASE_REGENERATE_PROJECT=1 to regenerate explicitly.'
fi
bash Scripts/test-core.sh
PHASE_TEST_LABEL=release bash Scripts/test-core.sh -c release
python3 -m unittest discover -s Tests -p 'test_*.py' -v 2>&1 | tee logs/v2-source-gates.log
for script in Scripts/*.sh; do bash -n "$script"; done
if command -v swiftc >/dev/null 2>&1; then
  parser="$(command -v swiftc)"
else
  parser="$ROOT/.tools/swift-6.2.4-RELEASE-ubuntu24.04-aarch64/usr/bin/swiftc"
fi
for target in arm64-apple-ios17.0 arm64-apple-macosx14.0; do
  {
    printf 'Syntax only (not SDK type checking): %s\n' "$target"
    "$parser" -frontend -parse -swift-version 5 -target "$target" App/*.swift App/Views/*.swift Tests/ApplePersistenceTests/*.swift
    printf 'PASS: syntax parse exit 0\n'
  } 2>&1 | tee "logs/syntax-$target.log"
done
printf '%s\n' 'PASS: available verification complete. Xcode/SwiftData/CloudKit/device tests remain separate.'
