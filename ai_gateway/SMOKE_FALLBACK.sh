#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# auth
set +u; [ -f ./.env ] && { set -a; source ./.env; set +a; }; set -u
AUTH="${LITELLM_MASTER_KEY:-}"
AUTH_HEADER=(-H "Authorization: Bearer ${AUTH}")

echo "== /v1/models (:4001) =="
curl -fsS http://localhost:4001/v1/models | jq -r '.data[].id' | head -n 20 || true

echo "== trigger high_stakes on code.router (:4001) =="
curl -fsS "${AUTH_HEADER[@]}" http://localhost:4001/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"code.router","metadata":{"high_stakes":true},"messages":[{"role":"user","content":"Return 2+2 only."}],"temperature":0}' \
  | jq -r '.choices[0].message.content' | sed -n '1,3p'

echo "== litellm_fb log (tail) =="
LOG=/data/stack/ai_gateway/logs/litellm.log
[ -f "$LOG" ] && tail -n 120 "$LOG" | sed -E 's#(Authorization: Bearer) .*#\1 ********#' || echo "log não encontrado"

# marca textual heurística
if [ -f "$LOG" ] && grep -qi 'fallback' "$LOG"; then
  echo "FALLBACK: detected"
else
  echo "FALLBACK: not detected"
fi
