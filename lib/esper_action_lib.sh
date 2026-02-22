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
