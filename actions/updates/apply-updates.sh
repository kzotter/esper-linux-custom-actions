#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$REPO_ROOT/lib/esper_action_lib.sh"

ACTION="apply-updates"
DISTRO="$(detect_distro)"
INIT="$(detect_init)"

PRIV="$(require_root_or_sudo || true)"
run_as() { if [ "${PRIV:-}" = "root" ]; then "$@"; else sudo "$@"; fi; }

if [ -z "${PRIV:-}" ]; then
  json_emit "error" "$ACTION" "$DISTRO" "$INIT" "requires root or sudo"
  exit 1
fi

# Guardrail: require explicit opt-in to prevent accidental weekend destruction.
ALLOW_UPDATES="${ALLOW_UPDATES:-no}"
if [ "$ALLOW_UPDATES" != "yes" ]; then
  json_emit "error" "$ACTION" "$DISTRO" "$INIT" "refusing to apply updates: set ALLOW_UPDATES=yes to proceed"
  exit 1
fi

# Optional: preview mode
DRY_RUN="${DRY_RUN:-no}"

# Debian/Ubuntu
if command_exists apt-get; then
  run_as apt-get update -y >/dev/null 2>&1 || { json_emit "error" "$ACTION" "$DISTRO" "$INIT" "apt-get update failed"; exit 1; }

  if [ "$DRY_RUN" = "yes" ]; then
    run_as apt-get -s upgrade >/dev/null 2>&1 || true
    json_emit "success" "$ACTION" "$DISTRO" "$INIT"
    exit 0
  fi

  run_as DEBIAN_FRONTEND=noninteractive apt-get upgrade -y || { json_emit "error" "$ACTION" "$DISTRO" "$INIT" "apt-get upgrade failed"; exit 1; }
  json_emit "success" "$ACTION" "$DISTRO" "$INIT"
  exit 0
fi

# RHEL-family
if command_exists dnf; then
  if [ "$DRY_RUN" = "yes" ]; then
    run_as dnf check-update -q >/dev/null 2>&1 || true
    json_emit "success" "$ACTION" "$DISTRO" "$INIT"
    exit 0
  fi
  run_as dnf -y upgrade || { json_emit "error" "$ACTION" "$DISTRO" "$INIT" "dnf upgrade failed"; exit 1; }
  json_emit "success" "$ACTION" "$DISTRO" "$INIT"
  exit 0
fi

if command_exists yum; then
  if [ "$DRY_RUN" = "yes" ]; then
    run_as yum check-update -q >/dev/null 2>&1 || true
    json_emit "success" "$ACTION" "$DISTRO" "$INIT"
    exit 0
  fi
  run_as yum -y update || { json_emit "error" "$ACTION" "$DISTRO" "$INIT" "yum update failed"; exit 1; }
  json_emit "success" "$ACTION" "$DISTRO" "$INIT"
  exit 0
fi

# Alpine
if command_exists apk; then
  if [ "$DRY_RUN" = "yes" ]; then
    run_as apk update >/dev/null 2>&1 || true
    json_emit "success" "$ACTION" "$DISTRO" "$INIT"
    exit 0
  fi
  run_as apk upgrade --no-interactive || { json_emit "error" "$ACTION" "$DISTRO" "$INIT" "apk upgrade failed"; exit 1; }
  json_emit "success" "$ACTION" "$DISTRO" "$INIT"
  exit 0
fi

json_emit "error" "$ACTION" "$DISTRO" "$INIT" "no supported package manager found (apt/dnf/yum/apk)"
exit 1
