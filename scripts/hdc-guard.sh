#!/usr/bin/env bash
# hdc-guard.sh — Hard block for raw HDC execution
# All device operations MUST go through scripts/run-device-protocol.
# This script is a development-time check, not a production security boundary.

set -euo pipefail

# The HDC binary path that is forbidden to invoke directly
HDC_BIN="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"

# Check if the first argument is the HDC binary path
if [[ "${1:-}" == "$HDC_BIN" ]]; then
  echo "BLOCKED: Direct HDC invocation is forbidden." >&2
  echo "Use: scripts/device-lease --device <target> acquire" >&2
  echo "Then: scripts/run-device-protocol --device <target> --lease <id> <manifest>" >&2
  exit 1
fi

# Check if the first argument is a known HDC subcommand (list, tconn, shell, etc.)
case "${1:-}" in
  list|tconn|shell|install|uninstall|file|aa|uitest|hilog|hidumper|snapshot_display)
    echo "BLOCKED: Raw HDC subcommand '$1' is forbidden." >&2
    echo "Use: scripts/device-lease --device <target> acquire" >&2
    echo "Then: scripts/run-device-protocol --device <target> --lease <id> <manifest>" >&2
    exit 1
    ;;
esac

# If we get here, the command is not HDC-related
exec "$@"

