#!/usr/bin/env bash
set -euo pipefail

command_exists() { command -v "$1" >/dev/null 2>&1; }

detect_distro() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "${ID:-unknown}"
  else
    echo "unknown"
  fi
}

detect_init() {
  if command_exists systemctl && [ -d /run/systemd/system ]; then
    echo "systemd"
  elif command_exists rc-service || [ -d /run/openrc ]; then
    echo "openrc"
  else
    echo "unknown"
  fi
}

detect_container_cli() {
  if command_exists docker; then
    echo "docker"
  elif command_exists nerdctl; then
    echo "nerdctl"
  elif command_exists podman; then
    echo "podman"
  else
    echo "none"
  fi
}

require_root_or_sudo() {
  if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    echo "root"
    return 0
  fi
  if command_exists sudo; then
    echo "sudo"
    return 0
  fi
  return 1
}

json_emit() {
  local status="$1"; shift
  local action="$1"; shift
  local distro="$1"; shift
  local init="$1"; shift
  local reason="${1:-}"

  if [ -n "$reason" ]; then
    printf '{"status":"%s","action":"%s","distro":"%s","init":"%s","reason":"%s"}\n' \
      "$status" "$action" "$distro" "$init" "$reason"
  else
    printf '{"status":"%s","action":"%s","distro":"%s","init":"%s"}\n' \
      "$status" "$action" "$distro" "$init"
  fi
}

json_escape() {
  # Minimal JSON string escaper for reasons/text fields.
  # Handles backslash, quote, newline, carriage return, tab.
  local s="${1:-}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

json_emit_data() {
  # Usage: json_emit_data <status> <action> <distro> <init> <data_json> [reason]
  # data_json must be a JSON object string like: {"foo":1}
  local status="$1"; shift
  local action="$1"; shift
  local distro="$1"; shift
  local init="$1"; shift
  local data_json="$1"; shift
  local reason="${1:-}"

  # Validate-ish: if empty, force {}
  if [ -z "${data_json:-}" ]; then
    data_json="{}"
  fi

  if [ -n "$reason" ]; then
    reason="$(json_escape "$reason")"
    printf '{"status":"%s","action":"%s","distro":"%s","init":"%s","data":%s,"reason":"%s"}\n' \
      "$status" "$action" "$distro" "$init" "$data_json" "$reason"
  else
    printf '{"status":"%s","action":"%s","distro":"%s","init":"%s","data":%s}\n' \
      "$status" "$action" "$distro" "$init" "$data_json"
  fi
}
