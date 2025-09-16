#!/usr/bin/env bash
set -euo pipefail
LVL="${LEVEL:-3}"
OUT="/data/stack/_logs/tree_data_L${LVL}.txt"
mkdir -p /data/stack/_logs
if command -v tree >/dev/null 2>&1; then
  tree -a -L "${LVL}" /data | sed 's/\x1B\[[0-9;]*[A-Za-z]//g' | tee "${OUT}" >/dev/null
else
  find /data -mindepth 1 -maxdepth "${LVL}" -printf '%y %M %u %g %8s %TY-%Tm-%Td %TH:%TM %p\n' \
    | sort | tee "${OUT}" >/dev/null
fi
echo "${OUT}"
