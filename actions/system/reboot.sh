#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$REPO_ROOT/lib/esper_action_lib.sh"

ACTION="reboot"
DISTRO="$(detect_distro)"
INIT="$(detect_init)"

PRIV="$(require_root_or_sudo || true)"
run_as() { if [ "${PRIV:-}" = "root" ]; then "$@"; else sudo "$@"; fi; }

if [ -z "${PRIV:-}" ]; then
  json_emit "error" "$ACTION" "$DISTRO" "$INIT" "requires root or sudo"
  exit 1
fi

# Prefer init-native reboot if available
if [ "$INIT" = "systemd" ] && command_exists systemctl; then
  run_as systemctl reboot || { json_emit "error" "$ACTION" "$DISTRO" "$INIT" "systemctl reboot failed"; exit 1; }
  exit 0
fi

# Fallback
if command_exists reboot; then
  run_as reboot || { json_emit "error" "$ACTION" "$DISTRO" "$INIT" "reboot command failed"; exit 1; }
  exit 0
fi

json_emit "error" "$ACTION" "$DISTRO" "$INIT" "no supported reboot mechanism found"
exit 1
