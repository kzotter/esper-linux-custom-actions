#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$REPO_ROOT/lib/esper_action_lib.sh"

ACTION="restart-docker-daemon"
DISTRO="$(detect_distro)"
INIT="$(detect_init)"

PRIV="$(require_root_or_sudo || true)"
run_as() { if [ "${PRIV:-}" = "root" ]; then "$@"; else sudo "$@"; fi; }

if [ -z "${PRIV:-}" ]; then
  json_emit "error" "$ACTION" "$DISTRO" "$INIT" "requires root or sudo"
  exit 1
fi

# Prefer init-native restart
if [ "$INIT" = "systemd" ] && command_exists systemctl; then
  run_as systemctl restart docker || { json_emit "error" "$ACTION" "$DISTRO" "$INIT" "failed to restart docker via systemd"; exit 1; }
  json_emit "success" "$ACTION" "$DISTRO" "$INIT"
  exit 0
fi

if [ "$INIT" = "openrc" ] && command_exists rc-service; then
  run_as rc-service docker restart || { json_emit "error" "$ACTION" "$DISTRO" "$INIT" "failed to restart docker via openrc"; exit 1; }
  json_emit "success" "$ACTION" "$DISTRO" "$INIT"
  exit 0
fi

json_emit "error" "$ACTION" "$DISTRO" "$INIT" "unsupported init system for restarting docker (systemd/openrc)"
exit 1
