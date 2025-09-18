#!/usr/bin/env bash
set -euo pipefail

# Move previous TXT logs from _logs to _archive/<ts>/logs
BASE_DIR="/data/stack"
LOGS_DIR="$BASE_DIR/_logs"
TS_DIR="$BASE_DIR/_archive/$(date -u +%Y%m%dT%H%M%SZ)/logs"

mkdir -p "$TS_DIR"

# Move only top-level .txt files from _logs
shopt -s nullglob
for f in "$LOGS_DIR"/*.txt; do
  # Skip if file is our current aggregator (pattern safeguard)
  mv -f "$f" "$TS_DIR/"
  echo "moved: $(basename "$f") -> $TS_DIR" >&2
done
shopt -u nullglob

echo "$TS_DIR"