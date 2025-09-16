#!/usr/bin/env bash
set -euo pipefail
cd /data/stack/ai_gateway

AUTH=$(grep -m1 '^LITELLM_MASTER_KEY=' /data/stack/ai_gateway/.env | cut -d= -f2-)
C0=$(curl -sS -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $AUTH" http://127.0.0.1:4000/v1/models || echo 000)
C1=$(curl -sS -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $AUTH" http://127.0.0.1:4001/v1/models || echo 000)
M0=$(curl -sS -H "Authorization: Bearer $AUTH" http://127.0.0.1:4000/v1/models | jq -r '.data[].id' | tr '\n' ',' | sed 's/,$//')
M1=$(curl -sS -H "Authorization: Bearer $AUTH" http://127.0.0.1:4001/v1/models | jq -r '.data[].id' | tr '\n' ',' | sed 's/,$//')
H_FAST=$(curl -sS -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $AUTH" -H 'Content-Type: application/json' -d '{"model":"fast","messages":[{"role":"user","content":"2+2? one digit"}],"temperature":0}' http://127.0.0.1:4000/v1/chat/completions || echo 000)
H_ROUT=$(curl -sS -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $AUTH" -H 'Content-Type: application/json' -d '{"model":"code.router","messages":[{"role":"user","content":"2+2?"}],"temperature":0}' http://127.0.0.1:4001/v1/chat/completions || echo 000)
H_HYB_L=$(curl -sS -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $AUTH" -H 'Content-Type: application/json' -d '{"model":"code.hybrid","messages":[{"role":"user","content":"2+2? one digit"}],"temperature":0}' http://127.0.0.1:4001/v1/chat/completions || echo 000)
docker stop ai_gateway-ollama-1 >/dev/null 2>&1 && sleep 3 || true
H_HYB_FB=$(curl -sS -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $AUTH" -H 'Content-Type: application/json' -d '{"model":"code.hybrid","metadata":{"high_stakes":true},"messages":[{"role":"user","content":"OK"}],"temperature":0}' http://127.0.0.1:4001/v1/chat/completions || echo 000)
docker start ai_gateway-ollama-1 >/dev/null 2>&1 && sleep 5 || true
OW=$(docker ps --format '{{.Names}}\t{{.Ports}}' | grep openwebui | sed -n '1p' || true)
QH=$(curl -sS -o /dev/null -w '%{http_code}' http://127.0.0.1:6333/readyz || echo 000)
printf 'SUMMARY :4000=%s :4001=%s MODELS4000=[%s] MODELS4001=[%s] fast=%s code.router=%s code.hybrid.local=%s code.hybrid.fb=%s openwebui="%s" qdrant=%s\n' "$C0" "$C1" "$M0" "$M1" "$H_FAST" "$H_ROUT" "$H_HYB_L" "$H_HYB_FB" "$OW" "$QH"
