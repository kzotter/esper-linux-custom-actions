#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$REPO_ROOT/lib/esper_action_lib.sh"

ACTION="set-brightness"
DISTRO="$(detect_distro)"
INIT="$(detect_init)"

LEVEL="${1:-}"
if [ -z "$LEVEL" ]; then
  json_emit "error" "$ACTION" "$DISTRO" "$INIT" "usage: script.sh 25|50|75|100"
  exit 1
fi

PRIV="$(require_root_or_sudo || true)"
run_as() { if [ "${PRIV:-}" = "root" ]; then "$@"; else sudo "$@"; fi; }

# brightnessctl preferred
if command_exists brightnessctl; then
  run_as brightnessctl set "${LEVEL}%" >/dev/null 2>&1 || {
    json_emit "error" "$ACTION" "$DISTRO" "$INIT" "brightnessctl failed"
    exit 1
  }
  json_emit "success" "$ACTION" "$DISTRO" "$INIT"
  exit 0
fi

# sysfs fallback
for dir in /sys/class/backlight/*; do
  [ -d "$dir" ] || continue
  max=$(cat "$dir/max_brightness")
  target=$(( max * LEVEL / 100 ))
  run_as sh -c "echo $target > $dir/brightness" || {
    json_emit "error" "$ACTION" "$DISTRO" "$INIT" "sysfs brightness write failed"
    exit 1
  }
  json_emit "success" "$ACTION" "$DISTRO" "$INIT"
  exit 0
done

json_emit "error" "$ACTION" "$DISTRO" "$INIT" "no supported brightness control found"
exit 1
