#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$REPO_ROOT/lib/esper_action_lib.sh"

ACTION="restart-network-interface"
DISTRO="$(detect_distro)"
INIT="$(detect_init)"

PRIV="$(require_root_or_sudo || true)"
run_as() { if [ "${PRIV:-}" = "root" ]; then "$@"; else sudo "$@"; fi; }

if [ -z "${PRIV:-}" ]; then
  json_emit "error" "$ACTION" "$DISTRO" "$INIT" "requires root or sudo"
  exit 1
fi

IFACE="${1:-}"
if [ -z "$IFACE" ]; then
  json_emit "error" "$ACTION" "$DISTRO" "$INIT" "usage: script.sh <interface>"
  exit 1
fi

# Prefer NetworkManager
if command_exists nmcli; then
  run_as nmcli dev disconnect "$IFACE" || true
  run_as nmcli dev connect "$IFACE" || { json_emit "error" "$ACTION" "$DISTRO" "$INIT" "failed to reconnect via nmcli: $IFACE"; exit 1; }
  json_emit "success" "$ACTION" "$DISTRO" "$INIT"
  exit 0
fi

# Fallback: ip link
if ! command_exists ip; then
  json_emit "error" "$ACTION" "$DISTRO" "$INIT" "missing command: ip (iproute2)"
  exit 1
fi

run_as ip link set "$IFACE" down || true
sleep 1
run_as ip link set "$IFACE" up || { json_emit "error" "$ACTION" "$DISTRO" "$INIT" "failed to bring interface up: $IFACE"; exit 1; }

json_emit "success" "$ACTION" "$DISTRO" "$INIT"
