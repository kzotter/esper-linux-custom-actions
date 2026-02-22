#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$REPO_ROOT/lib/esper_action_lib.sh"

ACTION="rotate-logs"
DISTRO="$(detect_distro)"
INIT="$(detect_init)"

PRIV="$(require_root_or_sudo || true)"
run_as() { if [ "${PRIV:-}" = "root" ]; then "$@"; else sudo "$@"; fi; }

if [ -z "${PRIV:-}" ]; then
  json_emit "error" "$ACTION" "$DISTRO" "$INIT" "requires root or sudo"
  exit 1
fi

# Preferred: logrotate if available
if command_exists logrotate; then
  CONF="/etc/logrotate.conf"
  if [ -f "$CONF" ]; then
    run_as logrotate -f "$CONF" >/dev/null 2>&1 || { json_emit "error" "$ACTION" "$DISTRO" "$INIT" "logrotate failed"; exit 1; }
    json_emit "success" "$ACTION" "$DISTRO" "$INIT"
    exit 0
  fi
fi

# Fallback: conservative compression of older logs (does NOT truncate active logs)
# Compress *.log and *.out older than 1 day in /var/log (common fleets)
DAYS="${DAYS:-1}"
if [ -d /var/log ] && command_exists find && command_exists gzip; then
  run_as find /var/log -type f \( -name "*.log" -o -name "*.out" \) -mtime +"$DAYS" -not -name "*.gz" -exec gzip -f {} \; >/dev/null 2>&1 || true
  json_emit "success" "$ACTION" "$DISTRO" "$INIT"
  exit 0
fi

json_emit "error" "$ACTION" "$DISTRO" "$INIT" "no supported log rotation method found (logrotate or /var/log+gzip)"
exit 1
