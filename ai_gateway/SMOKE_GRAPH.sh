#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

# Load env (for LITELLM_MASTER_KEY) and prepare Authorization header
set +u
if [ -f ./.env ]; then
  set -a; source ./.env; set +a
fi
set -u
AUTH_HEADER=(-H "Authorization: Bearer ${LITELLM_MASTER_KEY:-}")

echo "== [1] LiteLLM /v1/models (top ids) =="
curl -sS "${AUTH_HEADER[@]}" http://localhost:4000/v1/models \
  | jq -r '.data[].id' 2>/dev/null | head -n 10 \
  || curl -sS "${AUTH_HEADER[@]}" http://localhost:4000/v1/models | head -c 400
echo

echo "== [2] Qdrant /readyz =="
curl -sS http://localhost:6333/readyz || true
echo

echo "== [3] Insert note via MEM_CLI =="
docker exec ai_langgraph python /app/MEM_CLI.py "Nota: rotas code/docs/search ativas" || true
echo

echo "== [4] POST /docs (ok + short result) =="
RESP_DOCS="$(curl -sS -H 'Content-Type: application/json' \
  -d '{"query":"PRD curto..."}' \
  http://localhost:9099/docs || true)"
printf 'ok: %s\n' "$(printf '%s' "$RESP_DOCS" | jq -r '.ok // false' 2>/dev/null || echo false)"
printf '%s' "$RESP_DOCS" \
  | jq -r '(.result // .response.choices[0].message.content // "")' 2>/dev/null \
  | head -c 200
echo
echo

echo "== [5] POST /code (ok) =="
curl -sS -H 'Content-Type: application/json' \
  -d '{"query":"Create idempotent BENCH_NOW.sh ..."}' \
  http://localhost:9099/code \
  | jq -r '.ok // false' 2>/dev/null | sed 's/^/ok: /' || true
echo

