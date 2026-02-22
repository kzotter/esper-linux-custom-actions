#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Turn off then on (best-effort), using the existing bluetooth toggle script.
"$SCRIPT_DIR/script.sh" off || true
sleep 2
"$SCRIPT_DIR/script.sh" on
