#!/bin/bash
# Available checks only. This never pretends that parsing is an Apple SDK build.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
bash Scripts/generate-project.sh
bash Scripts/test-core.sh
PHASE_TEST_LABEL=release bash Scripts/test-core.sh -c release
python3 Tests/test_delivery.py 2>&1 | tee logs/delivery-green.log
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
