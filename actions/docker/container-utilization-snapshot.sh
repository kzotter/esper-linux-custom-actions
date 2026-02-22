#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$REPO_ROOT/lib/esper_action_lib.sh"

ACTION="container-utilization-snapshot"
DISTRO="$(detect_distro)"
INIT="$(detect_init)"
CONTAINER_CLI="$(detect_container_cli)"

if [ "$CONTAINER_CLI" = "none" ]; then
  json_emit_data "error" "$ACTION" "$DISTRO" "$INIT" "{}" "no container runtime found (docker/nerdctl/podman)"
  exit 1
fi

# docker stats --no-stream gives one snapshot
# Format: container, name, cpu%, mem_usage, mem%, net_io, block_io
FORMAT="{{.ID}},{{.Name}},{{.CPUPerc}},{{.MemUsage}},{{.MemPerc}},{{.NetIO}},{{.BlockIO}}"

OUT="$($CONTAINER_CLI stats --no-stream --format "$FORMAT" 2>/dev/null || true)"

if [ -z "$OUT" ]; then
  # No running containers is not necessarily an error
  data='{"containers":[]}'
  json_emit_data "success" "$ACTION" "$DISTRO" "$INIT" "$data"
  exit 0
fi

containers_json="["

while IFS= read -r line; do
  IFS=',' read -r cid name cpu mem_usage mem_perc net_io block_io <<<"$line"

  cid="$(json_escape "$cid")"
  name="$(json_escape "$name")"
  cpu="${cpu%\%}"
  mem_perc="${mem_perc%\%}"

  # mem_usage is like "12.34MiB / 512MiB"
  mem_used="$(echo "$mem_usage" | awk '{print $1}')"
  mem_total="$(echo "$mem_usage" | awk '{print $3}')"

  container_obj=$(printf '{"id":"%s","name":"%s","cpu_pct":"%s","mem_used":"%s","mem_total":"%s","mem_pct":"%s","net_io":"%s","block_io":"%s"}' \
    "$cid" "$name" "$cpu" "$mem_used" "$mem_total" "$mem_perc" \
    "$(json_escape "$net_io")" "$(json_escape "$block_io")")

  if [ "$containers_json" != "[" ]; then
    containers_json="${containers_json},"
  fi
  containers_json="${containers_json}${container_obj}"
done <<<"$OUT"

containers_json="${containers_json}]"

data=$(printf '{"containers":%s,"timestamp_utc":"%s"}' \
  "$containers_json" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")")

json_emit_data "success" "$ACTION" "$DISTRO" "$INIT" "$data"
