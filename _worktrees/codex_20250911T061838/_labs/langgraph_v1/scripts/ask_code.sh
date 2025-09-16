#!/usr/bin/env bash
set -euo pipefail
[ $# -ge 1 ] || { echo "usage: ask_code.sh \"prompt\"" >&2; exit 1; }
TXT="$*"
curl -sS localhost:8000/graph-code/invoke -H 'content-type: application/json' -d "{\"input\": \"$TXT\"}" | jq -r '.output'
