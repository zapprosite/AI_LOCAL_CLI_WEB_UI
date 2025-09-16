#!/usr/bin/env bash
set -euo pipefail
cd /data/stack/ai_gateway
AUTH=$(grep -m1 '^LITELLM_MASTER_KEY=' .env | cut -d= -f2-) || { echo "no AUTH"; exit 1; }

echo "== /v1/models @4001 =="
curl -sS -H "Authorization: Bearer $AUTH" http://localhost:4001/v1/models | jq -r '.data[].id' | sort

echo "== chat code.router 2+2 =="
RESP=$(curl -sS -H "Authorization: Bearer $AUTH" -H 'Content-Type: application/json' \
  http://localhost:4001/v1/chat/completions \
  -d '{"model":"code.router","messages":[{"role":"user","content":"2+2? Single digit."}],"temperature":0}')
CODE=$(jq -r '.choices[0].message.content' <<<"$RESP" | tr -dc '0-9')
[ "$CODE" = "4" ] || { echo "FAIL: expected 4, got: $RESP"; exit 2; }

echo "== chat docs.router short =="
curl -sS -H "Authorization: Bearer $AUTH" -H 'Content-Type: application/json' \
  http://localhost:4001/v1/chat/completions \
  -d '{"model":"docs.router","messages":[{"role":"user","content":"One-line PRD: routers for code/docs/search."}],"temperature":0.2}' | jq -r '.choices[0].message.content' | head -n1

echo "== chat search.router short =="
curl -sS -H "Authorization: Bearer $AUTH" -H 'Content-Type: application/json' \
  http://localhost:4001/v1/chat/completions \
  -d '{"model":"search.router","messages":[{"role":"user","content":"Answer yes/no: routers active?"}],"temperature":0}' | jq -r '.choices[0].message.content' | head -n1

echo "[OK] routers responding"
