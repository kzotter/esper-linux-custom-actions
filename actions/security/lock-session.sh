#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$REPO_ROOT/lib/esper_action_lib.sh"

ACTION="lock-session"
DISTRO="$(detect_distro)"
INIT="$(detect_init)"

PRIV="$(require_root_or_sudo || true)"
run_as() { if [ "${PRIV:-}" = "root" ]; then "$@"; else sudo "$@"; fi; }

# loginctl works without full root in many cases, but we keep consistency
if command_exists loginctl; then
  run_as loginctl lock-sessions >/dev/null 2>&1 || {
    json_emit "error" "$ACTION" "$DISTRO" "$INIT" "loginctl lock failed"
    exit 1
  }
  json_emit "success" "$ACTION" "$DISTRO" "$INIT"
  exit 0
fi

# Fallback: xdg-screensaver (X11 environments)
if command_exists xdg-screensaver; then
  xdg-screensaver lock >/dev/null 2>&1 || {
    json_emit "error" "$ACTION" "$DISTRO" "$INIT" "xdg-screensaver lock failed"
    exit 1
  }
  json_emit "success" "$ACTION" "$DISTRO" "$INIT"
  exit 0
fi

json_emit "error" "$ACTION" "$DISTRO" "$INIT" "no supported session lock mechanism found (loginctl/xdg-screensaver)"
exit 1
