#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$REPO_ROOT/lib/esper_action_lib.sh"

ACTION="kiosk-restart-app"
DISTRO="$(detect_distro)"
INIT="$(detect_init)"

SERVICE="${KIOSK_SERVICE:-}"

if [ -z "$SERVICE" ]; then
  json_emit "error" "$ACTION" "$DISTRO" "$INIT" "set KIOSK_SERVICE=<service-name>"
  exit 1
fi

PRIV="$(require_root_or_sudo || true)"
run_as() { if [ "${PRIV:-}" = "root" ]; then "$@"; else sudo "$@"; fi; }

if [ "$INIT" = "systemd" ] && command_exists systemctl; then
  run_as systemctl restart "$SERVICE" || {
    json_emit "error" "$ACTION" "$DISTRO" "$INIT" "failed to restart service $SERVICE"
    exit 1
  }
  json_emit "success" "$ACTION" "$DISTRO" "$INIT"
  exit 0
fi

json_emit "error" "$ACTION" "$DISTRO" "$INIT" "unsupported init system for kiosk restart"
exit 1
