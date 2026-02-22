#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../" && pwd)"

. "$REPO_ROOT/lib/esper_action_lib.sh"

ACTION="restart-container"
DISTRO="$(detect_distro)"
INIT="$(detect_init)"
CONTAINER_CLI="$(detect_container_cli)"

PRIV="$(require_root_or_sudo || true)"
if [ -z "${PRIV:-}" ]; then
  json_emit "error" "$ACTION" "$DISTRO" "$INIT" "requires root or sudo"
  exit 1
fi

run_as() {
  if [ "$PRIV" = "root" ]; then
    "$@"
  else
    sudo "$@"
  fi
}

if [ "$CONTAINER_CLI" = "none" ]; then
  json_emit "error" "$ACTION" "$DISTRO" "$INIT" "no container runtime found"
  exit 1
fi

NAME="${1:-}"
if [ -z "$NAME" ]; then
  json_emit "error" "$ACTION" "$DISTRO" "$INIT" "usage: restart-container <name>"
  exit 1
fi

run_as "$CONTAINER_CLI" restart "$NAME"

json_emit "success" "$ACTION" "$DISTRO" "$INIT"
