#!/usr/bin/env bash
set -euo pipefail
AUTH=$(grep -m1 '^LITELLM_MASTER_KEY=' .env|cut -d= -f2-)
echo "== CONTAINERS (status) =="
docker ps --format '{{.Names}}\t{{.Status}}\t{{.Image}}' | sort
echo "== HEALTH DETAILS =="
for c in ai_gateway-litellm-1 ai_gateway-litellm_fb-1 ai_gateway-qdrant-1 ai_gateway-ollama-1; do
  echo "-- $c"; docker inspect "$c" --format '{{.Name}} health={{if .State.Health}}{{.State.Health.Status}}{{else}}n/a{{end}} started={{.State.StartedAt}} restarts={{.RestartCount}}' || true
done
echo "== PORTS CHECK =="
for p in 4000 4001; do code=$(curl -sS -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $AUTH" "http://127.0.0.1:$p/v1/models" || echo 000); echo "PORT=$p HTTP=$code"; done
echo "== QDRANT =="
curl -sS http://127.0.0.1:6333/readyz || true
