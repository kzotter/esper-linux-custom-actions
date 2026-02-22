#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$REPO_ROOT/lib/esper_action_lib.sh"

ACTION="wifi-toggle"
DISTRO="$(detect_distro)"
INIT="$(detect_init)"

PRIV="$(require_root_or_sudo || true)"
run_as() { if [ "${PRIV:-}" = "root" ]; then "$@"; else sudo "$@"; fi; }

if [ -z "${PRIV:-}" ]; then
  json_emit "error" "$ACTION" "$DISTRO" "$INIT" "requires root or sudo"
  exit 1
fi

STATE="${1:-}"
if [ -z "$STATE" ]; then
  json_emit "error" "$ACTION" "$DISTRO" "$INIT" "usage: script.sh on|off"
  exit 1
fi

# Prefer NetworkManager
if command_exists nmcli; then
  case "$STATE" in
    on)  run_as nmcli radio wifi on ;;
    off) run_as nmcli radio wifi off ;;
    *) json_emit "error" "$ACTION" "$DISTRO" "$INIT" "invalid state: $STATE (use on|off)"; exit 1 ;;
  esac
  json_emit "success" "$ACTION" "$DISTRO" "$INIT"
  exit 0
fi

# Fallback: rfkill
if command_exists rfkill; then
  case "$STATE" in
    on)  run_as rfkill unblock wifi ;;
    off) run_as rfkill block wifi ;;
    *) json_emit "error" "$ACTION" "$DISTRO" "$INIT" "invalid state: $STATE (use on|off)"; exit 1 ;;
  esac
  json_emit "success" "$ACTION" "$DISTRO" "$INIT"
  exit 0
fi

json_emit "error" "$ACTION" "$DISTRO" "$INIT" "no supported WiFi control found (nmcli/rfkill)"
exit 1
