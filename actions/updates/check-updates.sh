#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$REPO_ROOT/lib/esper_action_lib.sh"

ACTION="check-updates"
DISTRO="$(detect_distro)"
INIT="$(detect_init)"

PRIV="$(require_root_or_sudo || true)"
run_as() { if [ "${PRIV:-}" = "root" ]; then "$@"; else sudo "$@"; fi; }

if [ -z "${PRIV:-}" ]; then
  json_emit "error" "$ACTION" "$DISTRO" "$INIT" "requires root or sudo"
  exit 1
fi

# Debian/Ubuntu
if command_exists apt-get; then
  run_as apt-get update -y >/dev/null 2>&1 || { json_emit "error" "$ACTION" "$DISTRO" "$INIT" "apt-get update failed"; exit 1; }
  json_emit "success" "$ACTION" "$DISTRO" "$INIT"
  exit 0
fi

# RHEL-family
if command_exists dnf; then
  # check-update returns non-zero when updates exist; that's not an error
  run_as dnf check-update -q >/dev/null 2>&1 || true
  json_emit "success" "$ACTION" "$DISTRO" "$INIT"
  exit 0
fi

if command_exists yum; then
  run_as yum check-update -q >/dev/null 2>&1 || true
  json_emit "success" "$ACTION" "$DISTRO" "$INIT"
  exit 0
fi

# Alpine
if command_exists apk; then
  run_as apk update >/dev/null 2>&1 || { json_emit "error" "$ACTION" "$DISTRO" "$INIT" "apk update failed"; exit 1; }
  json_emit "success" "$ACTION" "$DISTRO" "$INIT"
  exit 0
fi

json_emit "error" "$ACTION" "$DISTRO" "$INIT" "no supported package manager found (apt/dnf/yum/apk)"
exit 1
