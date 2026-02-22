#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$REPO_ROOT/lib/esper_action_lib.sh"

ACTION="usb-toggle"
DISTRO="$(detect_distro)"
INIT="$(detect_init)"

PRIV="$(require_root_or_sudo || true)"
run_as() { if [ "${PRIV:-}" = "root" ]; then "$@"; else sudo "$@"; fi; }

if [ -z "${PRIV:-}" ]; then
  json_emit "error" "$ACTION" "$DISTRO" "$INIT" "requires root or sudo"
  exit 1
fi

STATE="${1:-}"
if [ -z "$STATE" ]; then
  json_emit "error" "$ACTION" "$DISTRO" "$INIT" "usage: script.sh on|off"
  exit 1
fi

if [ ! -d /sys/bus/usb/devices ]; then
  json_emit "error" "$ACTION" "$DISTRO" "$INIT" "USB sysfs not found; unsupported platform"
  exit 1
fi

case "$STATE" in
  off)
    # De-authorize all USB devices (runtime only)
    for dev in /sys/bus/usb/devices/*/authorized; do
      [ -f "$dev" ] && run_as sh -c "echo 0 > $dev" || true
    done
    json_emit "success" "$ACTION" "$DISTRO" "$INIT"
    ;;
  on)
    for dev in /sys/bus/usb/devices/*/authorized; do
      [ -f "$dev" ] && run_as sh -c "echo 1 > $dev" || true
    done
    json_emit "success" "$ACTION" "$DISTRO" "$INIT"
    ;;
  *)
    json_emit "error" "$ACTION" "$DISTRO" "$INIT" "invalid state: $STATE (use on|off)"
    exit 1
    ;;
esac
