#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$REPO_ROOT/lib/esper_action_lib.sh"

ACTION="clear-temp"
DISTRO="$(detect_distro)"
INIT="$(detect_init)"

PRIV="$(require_root_or_sudo || true)"
run_as() { if [ "${PRIV:-}" = "root" ]; then "$@"; else sudo "$@"; fi; }

if [ -z "${PRIV:-}" ]; then
  json_emit "error" "$ACTION" "$DISTRO" "$INIT" "requires root or sudo"
  exit 1
fi

# Safety guard: only delete inside known temp dirs
run_as find /tmp /var/tmp -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || {
  json_emit "error" "$ACTION" "$DISTRO" "$INIT" "failed clearing /tmp or /var/tmp"
  exit 1
}

json_emit "success" "$ACTION" "$DISTRO" "$INIT"
