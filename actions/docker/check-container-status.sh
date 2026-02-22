#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$REPO_ROOT/lib/esper_action_lib.sh"

ACTION="check-container-status"
DISTRO="$(detect_distro)"
INIT="$(detect_init)"
CONTAINER_CLI="$(detect_container_cli)"

PRIV="$(require_root_or_sudo || true)"
run_as() { if [ "${PRIV:-}" = "root" ]; then "$@"; else sudo "$@"; fi; }

if [ -z "${PRIV:-}" ]; then
  json_emit "error" "$ACTION" "$DISTRO" "$INIT" "requires root or sudo"
  exit 1
fi

NAME="${1:-}"
if [ -z "$NAME" ]; then
  json_emit "error" "$ACTION" "$DISTRO" "$INIT" "usage: script.sh <container-name>"
  exit 1
fi

if [ "$CONTAINER_CLI" = "none" ]; then
  json_emit "error" "$ACTION" "$DISTRO" "$INIT" "no container runtime found (docker/nerdctl/podman)"
  exit 1
fi

# Confirm existence
if ! run_as "$CONTAINER_CLI" ps -a --format '{{.Names}}' | grep -qx "$NAME"; then
  json_emit "error" "$ACTION" "$DISTRO" "$INIT" "container not found: $NAME"
  exit 1
fi

# Minimal check: if it exists, we succeed.
# Later we can extend lib/json_emit to support a data payload with state/health.
run_as "$CONTAINER_CLI" ps --filter "name=$NAME" >/dev/null

json_emit "success" "$ACTION" "$DISTRO" "$INIT"
