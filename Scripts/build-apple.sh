#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if [ "$(uname -s)" != Darwin ] || ! command -v xcodebuild >/dev/null 2>&1; then
  printf '%s\n' 'error: Apple builds/tests require macOS with full Xcode selected. Linux syntax checks are not an Apple build.' >&2
  exit 1
fi
mkdir -p logs
mode="${1:-local}"
case "$mode" in
  local)
    xcodebuild -project PhaseSystem.xcodeproj -scheme PhaseSystem -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/apple-ios CODE_SIGNING_ALLOWED=NO build 2>&1 | tee logs/apple-ios-build.log
    xcodebuild -project PhaseSystem.xcodeproj -scheme PhaseSystemMac -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/apple-mac CODE_SIGNING_ALLOWED=NO build 2>&1 | tee logs/apple-mac-build.log
    ;;
  test)
    xcodebuild -project PhaseSystem.xcodeproj -scheme PhaseSystemMac -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/apple-tests CODE_SIGNING_ALLOWED=NO test 2>&1 | tee logs/apple-persistence-tests.log
    ;;
  cloud)
    # Requires Config/Cloud.xcconfig, enrolled bundle IDs, container and real profiles.
    xcodebuild -project PhaseSystem.xcodeproj -scheme PhaseSystemCloud -configuration CloudDebug -destination 'generic/platform=iOS' -derivedDataPath .build/apple-cloud-ios -allowProvisioningUpdates build 2>&1 | tee logs/apple-cloud-ios-build.log
    xcodebuild -project PhaseSystem.xcodeproj -scheme PhaseSystemMacCloud -configuration CloudDebug -destination 'platform=macOS' -derivedDataPath .build/apple-cloud-mac -allowProvisioningUpdates build 2>&1 | tee logs/apple-cloud-mac-build.log
    ;;
  *) printf '%s\n' 'Usage: bash Scripts/build-apple.sh [local|test|cloud]' >&2; exit 2 ;;
esac
