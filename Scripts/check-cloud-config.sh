#!/bin/bash
set -eu
case "${CONFIGURATION:-Debug}" in
  CloudDebug|CloudRelease)
    if [ -z "${DEVELOPMENT_TEAM:-}" ]; then
      printf '%s\n' 'error: Set DEVELOPMENT_TEAM in Config/Cloud.xcconfig.' >&2
      exit 1
    fi
    case "${PHASE_CLOUDKIT_CONTAINER:-}" in
      iCloud.*) ;;
      *) printf '%s\n' 'error: Set PHASE_CLOUDKIT_CONTAINER to your iCloud.* container in Config/Cloud.xcconfig.' >&2; exit 1 ;;
    esac
    case "${PHASE_CLOUDKIT_CONTAINER:-}" in
      *'$('*|*' '*|*'example'*|*'YOUR'*) printf '%s\n' 'error: Replace the CloudKit placeholder with a real enrolled container.' >&2; exit 1 ;;
    esac
    ;;
esac
