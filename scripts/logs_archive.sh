#!/usr/bin/env bash
set -euo pipefail

# Move previous TXT logs from _logs to _archive/<ts>/logs
# Also rotate old _logs/logcodex_*.md to _archive/<ts>/logcodex/
BASE_DIR="/data/stack"
LOGS_DIR="$BASE_DIR/_logs"
TS_BASE="$BASE_DIR/_archive/$(date -u +%Y%m%dT%H%M%SZ)"
TS_LOGS_DIR="$TS_BASE/logs"
TS_CODEX_DIR="$TS_BASE/logcodex"

mkdir -p "$TS_LOGS_DIR" "$TS_CODEX_DIR"

# Move only top-level .txt files from _logs
shopt -s nullglob
for f in "$LOGS_DIR"/*.txt; do
  mv -f "$f" "$TS_LOGS_DIR/"
  echo "moved: $(basename "$f") -> $TS_LOGS_DIR" >&2
done

# Move timestamped logcodex markdowns
for f in "$LOGS_DIR"/logcodex_*.md; do
  mv -f "$f" "$TS_CODEX_DIR/" || true
  echo "moved: $(basename "$f") -> $TS_CODEX_DIR" >&2 || true
done
shopt -u nullglob

echo "$TS_BASE"