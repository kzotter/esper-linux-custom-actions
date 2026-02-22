#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$REPO_ROOT/lib/esper_action_lib.sh"

ACTION="host-telemetry-snapshot"
DISTRO="$(detect_distro)"
INIT="$(detect_init)"

# --- helpers ---
num_or_str() {
  local v="${1:-}"
  if [[ "$v" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
    printf '%s' "$v"
  else
    v="$(json_escape "$v")"
    printf '"%s"' "$v"
  fi
}

timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# --- load averages ---
load_1="N/A"; load_5="N/A"; load_15="N/A"
if [ -r /proc/loadavg ]; then
  read -r load_1 load_5 load_15 _ < /proc/loadavg || true
fi

# --- memory ---
mem_total_kib="N/A"; mem_avail_kib="N/A"; mem_used_kib="N/A"
if [ -r /proc/meminfo ]; then
  mem_total_kib="$(awk '/MemTotal:/ {print $2; exit}' /proc/meminfo || echo N/A)"
  mem_avail_kib="$(awk '/MemAvailable:/ {print $2; exit}' /proc/meminfo || echo N/A)"
  if [[ "$mem_total_kib" =~ ^[0-9]+$ ]] && [[ "$mem_avail_kib" =~ ^[0-9]+$ ]]; then
    mem_used_kib=$(( mem_total_kib - mem_avail_kib ))
  fi
fi

# --- disk ---
# Default to root filesystem. Override with PATH_TO_CHECK=/somewhere
PATH_TO_CHECK="${PATH_TO_CHECK:-/}"
disk_total_kib="N/A"; disk_used_kib="N/A"; disk_avail_kib="N/A"; disk_use_pct="N/A"

if command_exists df; then
  # df -Pk: POSIX-ish, consistent KiB units
  # Output: Filesystem 1024-blocks Used Available Capacity Mounted on
  line="$(df -Pk "$PATH_TO_CHECK" 2>/dev/null | tail -n1 || true)"
  if [ -n "$line" ]; then
    disk_total_kib="$(echo "$line" | awk '{print $2}')"
    disk_used_kib="$(echo "$line"  | awk '{print $3}')"
    disk_avail_kib="$(echo "$line" | awk '{print $4}')"
    disk_use_pct="$(echo "$line"   | awk '{print $5}' | tr -d '%')"
  fi
fi

# --- uptime ---
uptime_seconds="N/A"
if [ -r /proc/uptime ]; then
  uptime_seconds="$(awk '{print int($1)}' /proc/uptime 2>/dev/null || echo N/A)"
fi

data=$(printf '{"timestamp_utc":"%s","load_avg":{"1m":%s,"5m":%s,"15m":%s},"memory_kib":{"total":%s,"used":%s,"available":%s},"disk_kib":{"path":"%s","total":%s,"used":%s,"available":%s,"use_pct":%s},"uptime_seconds":%s}' \
  "$timestamp" \
  "$(num_or_str "$load_1")" "$(num_or_str "$load_5")" "$(num_or_str "$load_15")" \
  "$(num_or_str "$mem_total_kib")" "$(num_or_str "$mem_used_kib")" "$(num_or_str "$mem_avail_kib")" \
  "$(json_escape "$PATH_TO_CHECK")" \
  "$(num_or_str "$disk_total_kib")" "$(num_or_str "$disk_used_kib")" "$(num_or_str "$disk_avail_kib")" "$(num_or_str "$disk_use_pct")" \
  "$(num_or_str "$uptime_seconds")")

json_emit_data "success" "$ACTION" "$DISTRO" "$INIT" "$data"
