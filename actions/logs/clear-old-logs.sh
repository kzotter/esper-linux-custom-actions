#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$REPO_ROOT/lib/esper_action_lib.sh"

ACTION="clear-old-logs"
DISTRO="$(detect_distro)"
INIT="$(detect_init)"

PRIV="$(require_root_or_sudo || true)"
run_as() { if [ "${PRIV:-}" = "root" ]; then "$@"; else sudo "$@"; fi; }

if [ -z "${PRIV:-}" ]; then
  json_emit "error" "$ACTION" "$DISTRO" "$INIT" "requires root or sudo"
  exit 1
fi

# Guardrails: default to conservative retention
# Either keep last N days of journal OR cap total size.
RETENTION_DAYS="${RETENTION_DAYS:-7}"
MAX_JOURNAL_SIZE="${MAX_JOURNAL_SIZE:-200M}"

# systemd-journald vacuuming
if command_exists journalctl; then
  # Prefer size cap, then time-based vacuum
  run_as journalctl --vacuum-size="$MAX_JOURNAL_SIZE" >/dev/null 2>&1 || true
  run_as journalctl --vacuum-time="${RETENTION_DAYS}d" >/dev/null 2>&1 || true
  json_emit "success" "$ACTION" "$DISTRO" "$INIT"
  exit 0
fi

# Non-systemd fallback: delete rotated/compressed logs older than N days
if [ -d /var/log ] && command_exists find; then
  run_as find /var/log -type f \( -name "*.gz" -o -name "*.1" -o -name "*.old" -o -name "*.[0-9]" -o -name "*.[0-9][0-9]" \) -mtime +"$RETENTION_DAYS" -delete >/dev/null 2>&1 || true
  json_emit "success" "$ACTION" "$DISTRO" "$INIT"
  exit 0
fi

json_emit "error" "$ACTION" "$DISTRO" "$INIT" "no supported log cleanup method found (journalctl or /var/log)"
exit 1
