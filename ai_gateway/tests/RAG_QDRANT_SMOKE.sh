#!/usr/bin/env sh
set -eu
QDR="${QDR:-http://127.0.0.1:6333}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "MISSING:$1"; exit 1; }; }
need curl; need jq

COL="smoke_cli"
echo "== readyz =="; curl -sS "${QDR}/readyz" | sed -n '1,3p'

echo "== create collection =="
curl -sS -X PUT "${QDR}/collections/${COL}" -H "Content-Type: application/json" \
  -d '{"vectors":{"size":3,"distance":"Cosine"}}' \
| jq -r '.status, (.result.status? // .result? // empty)' || true

echo "== upsert points =="
UPS='{"points":[
  {"id":1,"vector":[0.1,0.2,0.3],"payload":{"k":"v1"}},
  {"id":2,"vector":[0.9,0.1,0.2],"payload":{"k":"v2"}}
]}'
curl -sS -X PUT "${QDR}/collections/${COL}/points?wait=true" -H "Content-Type: application/json" -d "$UPS" \
| jq -r '.status, (.result.status? // .result? // empty)' || true

echo "== search =="
Q='{"vector":[0.1,0.2,0.31],"limit":2}'
curl -sS -X POST "${QDR}/collections/${COL}/points/search" -H "Content-Type: application/json" -d "$Q" \
| jq -r '.result[]?.id, .result[]?.score' || true
