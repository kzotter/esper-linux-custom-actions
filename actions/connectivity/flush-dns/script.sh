#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$REPO_ROOT/lib/esper_action_lib.sh"

ACTION="flush-dns"
DISTRO="$(detect_distro)"
INIT="$(detect_init)"

PRIV="$(require_root_or_sudo || true)"
run_as() { if [ "${PRIV:-}" = "root" ]; then "$@"; else sudo "$@"; fi; }

if [ -z "${PRIV:-}" ]; then
  json_emit "error" "$ACTION" "$DISTRO" "$INIT" "requires root or sudo"
  exit 1
fi

# systemd-resolved
if command_exists resolvectl; then
  run_as resolvectl flush-caches
  json_emit "success" "$ACTION" "$DISTRO" "$INIT"
  exit 0
fi

# older systemd
if command_exists systemd-resolve; then
  run_as systemd-resolve --flush-caches
  json_emit "success" "$ACTION" "$DISTRO" "$INIT"
  exit 0
fi

# nscd
if command_exists nscd; then
  run_as nscd -i hosts
  json_emit "success" "$ACTION" "$DISTRO" "$INIT"
  exit 0
fi

# dnsmasq (common on embedded)
if command_exists pkill; then
  run_as pkill -HUP dnsmasq 2>/dev/null && { json_emit "success" "$ACTION" "$DISTRO" "$INIT"; exit 0; }
fi

json_emit "error" "$ACTION" "$DISTRO" "$INIT" "no supported DNS cache flush found (resolvectl/systemd-resolve/nscd/dnsmasq)"
exit 1
