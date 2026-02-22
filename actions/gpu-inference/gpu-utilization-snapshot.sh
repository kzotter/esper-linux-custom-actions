#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$REPO_ROOT/lib/esper_action_lib.sh"

ACTION="gpu-utilization-snapshot"
DISTRO="$(detect_distro)"
INIT="$(detect_init)"

if ! command_exists nvidia-smi; then
  json_emit_data "error" "$ACTION" "$DISTRO" "$INIT" "{}" "nvidia-smi not found (NVIDIA drivers/tools not installed)"
  exit 1
fi

# Query a compact set of operationally useful fields.
# Format: CSV without units/headers, one line per GPU.
FIELDS="index,uuid,name,temperature.gpu,utilization.gpu,utilization.memory,memory.total,memory.used,power.draw,power.limit"

# If the driver is unhappy, nvidia-smi can exit non-zero.
OUT="$(nvidia-smi --query-gpu="$FIELDS" --format=csv,noheader,nounits 2>/dev/null || true)"
if [ -z "$OUT" ]; then
  json_emit_data "error" "$ACTION" "$DISTRO" "$INIT" "{}" "nvidia-smi returned no data (driver not loaded, GPU unavailable, or permissions issue)"
  exit 1
fi

# Convert CSV lines into a JSON array. Avoid jq dependency.
# Each line: index, uuid, name, temp, util.gpu, util.mem, mem.total, mem.used, pwr.draw, pwr.limit
gpus_json="["

# shellcheck disable=SC2162
while IFS= read -r line; do
  # Split on comma+space to be robust against names containing commas (rare but possible).
  # nvidia-smi tends to output comma+space separators.
  IFS=',' read -r idx uuid name temp util_gpu util_mem mem_total mem_used pwr_draw pwr_limit <<<"$line"

  # Trim leading spaces
  idx="${idx## }"; uuid="${uuid## }"; name="${name## }"; temp="${temp## }"
  util_gpu="${util_gpu## }"; util_mem="${util_mem## }"
  mem_total="${mem_total## }"; mem_used="${mem_used## }"
  pwr_draw="${pwr_draw## }"; pwr_limit="${pwr_limit## }"

  # Some fields may be "N/A" depending on GPU/driver; keep them as strings if not numeric.
  # We'll emit numbers when they look numeric; otherwise emit quoted strings.
  num_or_str() {
    local v="${1:-}"
    if [[ "$v" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
      printf '%s' "$v"
    else
      v="$(json_escape "$v")"
      printf '"%s"' "$v"
    fi
  }

  # Escape strings
  uuid="$(json_escape "$uuid")"
  name="$(json_escape "$name")"

  gpu_obj=$(printf '{"index":%s,"uuid":"%s","name":"%s","temperature_c":%s,"utilization_gpu_pct":%s,"utilization_mem_pct":%s,"memory_total_mib":%s,"memory_used_mib":%s,"power_draw_w":%s,"power_limit_w":%s}' \
    "$(num_or_str "$idx")" "$uuid" "$name" \
    "$(num_or_str "$temp")" "$(num_or_str "$util_gpu")" "$(num_or_str "$util_mem")" \
    "$(num_or_str "$mem_total")" "$(num_or_str "$mem_used")" \
    "$(num_or_str "$pwr_draw")" "$(num_or_str "$pwr_limit")")

  # Append with comma if needed
  if [ "$gpus_json" != "[" ]; then
    gpus_json="${gpus_json},"
  fi
  gpus_json="${gpus_json}${gpu_obj}"
done <<<"$OUT"

gpus_json="${gpus_json}]"

data=$(printf '{"gpus":%s,"timestamp_utc":"%s"}' "$gpus_json" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")")

json_emit_data "success" "$ACTION" "$DISTRO" "$INIT" "$data"
