#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$REPO_ROOT/lib/esper_action_lib.sh"

ACTION="pull-restart-container"
DISTRO="$(detect_distro)"
INIT="$(detect_init)"
CONTAINER_CLI="$(detect_container_cli)"

PRIV="$(require_root_or_sudo || true)"
run_as() { if [ "${PRIV:-}" = "root" ]; then "$@"; else sudo "$@"; fi; }

if [ -z "${PRIV:-}" ]; then
  json_emit "error" "$ACTION" "$DISTRO" "$INIT" "requires root or sudo"
  exit 1
fi

if [ "$CONTAINER_CLI" = "none" ]; then
  json_emit "error" "$ACTION" "$DISTRO" "$INIT" "no container runtime found (docker/nerdctl/podman)"
  exit 1
fi

IMAGE="${1:-}"
NAME="${2:-}"
if [ -z "$IMAGE" ] || [ -z "$NAME" ]; then
  json_emit "error" "$ACTION" "$DISTRO" "$INIT" "usage: script.sh <image> <container-name>"
  exit 1
fi

run_as "$CONTAINER_CLI" pull "$IMAGE" || { json_emit "error" "$ACTION" "$DISTRO" "$INIT" "failed to pull image: $IMAGE"; exit 1; }
run_as "$CONTAINER_CLI" restart "$NAME" || { json_emit "error" "$ACTION" "$DISTRO" "$INIT" "failed to restart container: $NAME"; exit 1; }

json_emit "success" "$ACTION" "$DISTRO" "$INIT"
