#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$REPO_ROOT/lib/esper_action_lib.sh"

ACTION="restart-inference-service"
DISTRO="$(detect_distro)"
INIT="$(detect_init)"

SERVICE="${INFERENCE_SERVICE:-inference}"

PRIV="$(require_root_or_sudo || true)"
run_as() { if [ "${PRIV:-}" = "root" ]; then "$@"; else sudo "$@"; fi; }

if [ -z "${PRIV:-}" ]; then
  json_emit "error" "$ACTION" "$DISTRO" "$INIT" "requires root or sudo"
  exit 1
fi

if [ "$INIT" = "systemd" ] && command_exists systemctl; then
  # Check exists
  run_as systemctl status "$SERVICE" >/dev/null 2>&1 || {
    json_emit "error" "$ACTION" "$DISTRO" "$INIT" "service not found or not runnable: $SERVICE"
    exit 1
  }
  run_as systemctl restart "$SERVICE" || {
    json_emit "error" "$ACTION" "$DISTRO" "$INIT" "failed to restart service: $SERVICE"
    exit 1
  }
  json_emit "success" "$ACTION" "$DISTRO" "$INIT"
  exit 0
fi

if [ "$INIT" = "openrc" ] && command_exists rc-service; then
  run_as rc-service "$SERVICE" status >/dev/null 2>&1 || {
    json_emit "error" "$ACTION" "$DISTRO" "$INIT" "service not found or not runnable: $SERVICE"
    exit 1
  }
  run_as rc-service "$SERVICE" restart || {
    json_emit "error" "$ACTION" "$DISTRO" "$INIT" "failed to restart service: $SERVICE"
    exit 1
  }
  json_emit "success" "$ACTION" "$DISTRO" "$INIT"
  exit 0
fi

json_emit "error" "$ACTION" "$DISTRO" "$INIT" "unsupported init system for service restart (systemd/openrc)"
exit 1
