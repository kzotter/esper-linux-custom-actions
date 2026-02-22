#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$REPO_ROOT/lib/esper_action_lib.sh"

ACTION="disk-space-check"
DISTRO="$(detect_distro)"
INIT="$(detect_init)"

if ! command_exists df; then
  json_emit "error" "$ACTION" "$DISTRO" "$INIT" "missing command: df"
  exit 1
fi

# Default to checking root filesystem; override with PATH_TO_CHECK env var
PATH_TO_CHECK="${PATH_TO_CHECK:-/}"

df -h "$PATH_TO_CHECK" >/dev/null || { json_emit "error" "$ACTION" "$DISTRO" "$INIT" "df failed for $PATH_TO_CHECK"; exit 1; }

json_emit "success" "$ACTION" "$DISTRO" "$INIT"
