#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$REPO_ROOT/lib/esper_action_lib.sh"

ACTION="check-gpu-status"
DISTRO="$(detect_distro)"
INIT="$(detect_init)"

if ! command_exists nvidia-smi; then
  json_emit "error" "$ACTION" "$DISTRO" "$INIT" "nvidia-smi not found (NVIDIA drivers/tools not installed)"
  exit 1
fi

# Run the basic command; suppress output for now since our json_emit doesn't include payloads yet.
nvidia-smi >/dev/null 2>&1 || {
  json_emit "error" "$ACTION" "$DISTRO" "$INIT" "nvidia-smi failed (driver not loaded or GPU unavailable)"
  exit 1
}

json_emit "success" "$ACTION" "$DISTRO" "$INIT"
