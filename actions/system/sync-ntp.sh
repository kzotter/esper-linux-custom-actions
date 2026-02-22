#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$REPO_ROOT/lib/esper_action_lib.sh"

ACTION="sync-ntp"
DISTRO="$(detect_distro)"
INIT="$(detect_init)"

PRIV="$(require_root_or_sudo || true)"
run_as() { if [ "${PRIV:-}" = "root" ]; then "$@"; else sudo "$@"; fi; }

if [ -z "${PRIV:-}" ]; then
  json_emit "error" "$ACTION" "$DISTRO" "$INIT" "requires root or sudo"
  exit 1
fi

# systemd-timesyncd / timedatectl
if command_exists timedatectl; then
  run_as timedatectl set-ntp true >/dev/null 2>&1 || true
  # Try a manual sync hint if available
  run_as timedatectl timesync-status >/dev/null 2>&1 || true
  json_emit "success" "$ACTION" "$DISTRO" "$INIT"
  exit 0
fi

# ntpdate fallback (if installed)
if command_exists ntpdate; then
  NTP_SERVER="${NTP_SERVER:-pool.ntp.org}"
  run_as ntpdate -u "$NTP_SERVER" >/dev/null 2>&1 || { json_emit "error" "$ACTION" "$DISTRO" "$INIT" "ntpdate failed against $NTP_SERVER"; exit 1; }
  json_emit "success" "$ACTION" "$DISTRO" "$INIT"
  exit 0
fi

# chrony fallback (if installed)
if command_exists chronyc; then
  run_as chronyc -a makestep >/dev/null 2>&1 || { json_emit "error" "$ACTION" "$DISTRO" "$INIT" "chronyc makestep failed"; exit 1; }
  json_emit "success" "$ACTION" "$DISTRO" "$INIT"
  exit 0
fi

json_emit "error" "$ACTION" "$DISTRO" "$INIT" "no supported NTP sync mechanism found (timedatectl/ntpdate/chronyc)"
exit 1
