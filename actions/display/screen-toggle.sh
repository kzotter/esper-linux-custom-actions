#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$REPO_ROOT/lib/esper_action_lib.sh"

ACTION="screen-toggle"
DISTRO="$(detect_distro)"
INIT="$(detect_init)"

STATE="${1:-}"
if [ -z "$STATE" ]; then
  json_emit "error" "$ACTION" "$DISTRO" "$INIT" "usage: script.sh on|off"
  exit 1
fi

# X11 method
if command_exists xset && [ -n "${DISPLAY:-}" ]; then
  case "$STATE" in
    off) xset dpms force off ;;
    on)  xset dpms force on ;;
    *) json_emit "error" "$ACTION" "$DISTRO" "$INIT" "invalid state: $STATE (use on|off)"; exit 1 ;;
  esac
  json_emit "success" "$ACTION" "$DISTRO" "$INIT"
  exit 0
fi

json_emit "error" "$ACTION" "$DISTRO" "$INIT" "no supported screen control mechanism found (xset)"
exit 1
