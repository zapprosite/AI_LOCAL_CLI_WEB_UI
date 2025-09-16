#!/usr/bin/env bash
set -euo pipefail
AUTH=$(grep -m1 '^LITELLM_MASTER_KEY=' /data/stack/ai_gateway/.env | cut -d= -f2-)
echo ">>> MODELS :4000 / :4001"
for P in 4000 4001; do curl -sS -H "Authorization: Bearer $AUTH" http://127.0.0.1:$P/v1/models | jq -r '.data[].id' | sort || true; done
echo ">>> code.router"
curl -sS -H "Authorization: Bearer $AUTH" -H 'Content-Type: application/json' -d '{"model":"code.router","messages":[{"role":"user","content":"2+2?"}],"temperature":0}' http://127.0.0.1:4001/v1/chat/completions | jq -r '.model,.choices[0].message.content'
echo ">>> code.hybrid (local)"
curl -sS -H "Authorization: Bearer $AUTH" -H 'Content-Type: application/json' -d '{"model":"code.hybrid","messages":[{"role":"user","content":"2+2? one digit"}],"temperature":0}' http://127.0.0.1:4001/v1/chat/completions | jq -r '.model,.choices[0].message.content'
