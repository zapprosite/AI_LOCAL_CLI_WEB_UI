#!/usr/bin/env bash
set -euo pipefail
TIMEOUT_MIN="${TIMEOUT_MIN:-15}"
LOG="/data/stack/_logs/codex_watchdog_$(date -u +%Y%m%dT%H%M%SZ).log"
exec > >(tee -a "$LOG") 2>&1
echo "start: $(date -Is)"
timeout "${TIMEOUT_MIN}m" codex "$@"
RC=$?; echo "end rc=$RC at $(date -Is)"; exit $RC
