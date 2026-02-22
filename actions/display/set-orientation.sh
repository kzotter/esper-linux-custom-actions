#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$REPO_ROOT/lib/esper_action_lib.sh"

ACTION="set-orientation"
DISTRO="$(detect_distro)"
INIT="$(detect_init)"

ORIENTATION="${1:-}"
if [ -z "$ORIENTATION" ]; then
  json_emit "error" "$ACTION" "$DISTRO" "$INIT" "usage: script.sh normal|left|right|inverted"
  exit 1
fi

if ! command_exists xrandr; then
  json_emit "error" "$ACTION" "$DISTRO" "$INIT" "xrandr not found (X11 required)"
  exit 1
fi

DISPLAY_NAME=$(xrandr | awk '/ connected/{print $1; exit}')

case "$ORIENTATION" in
  normal|left|right|inverted)
    xrandr --output "$DISPLAY_NAME" --rotate "$ORIENTATION" || {
      json_emit "error" "$ACTION" "$DISTRO" "$INIT" "xrandr rotation failed"
      exit 1
    }
    ;;
  *)
    json_emit "error" "$ACTION" "$DISTRO" "$INIT" "invalid orientation"
    exit 1
    ;;
esac

json_emit "success" "$ACTION" "$DISTRO" "$INIT"
