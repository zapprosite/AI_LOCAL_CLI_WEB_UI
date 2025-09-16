#!/usr/bin/env bash
set -Eeuo pipefail

COMPOSE=/data/stack/ai_gateway/docker-compose.stack.yml
L_ID="$(docker compose -f "$COMPOSE" ps -q litellm || true)"
[ -n "${L_ID:-}" ] || { echo "ERRO: container litellm não encontrado no projeto ai_gateway"; exit 1; }

echo "== DNS dentro do litellm =="
docker exec -i "$L_ID" getent hosts ollama || echo "FAIL: DNS ollama"
docker exec -i "$L_ID" getent hosts qdrant || echo "FAIL: DNS qdrant"

echo; echo "== HTTP interno a partir do litellm =="
docker exec -i "$L_ID" sh -lc 'which wget >/dev/null 2>&1 && wget -qO- http://ollama:11434/api/tags | head -c 120 || curl -fsS http://ollama:11434/api/tags | head -c 120' || true
echo
docker exec -i "$L_ID" sh -lc 'curl -fsS http://qdrant:6333/readyz' || true
echo

echo "== Host localhost probes =="
wget -qO- http://127.0.0.1:11434/api/tags | head -c 120 || true; echo
wget -qO- http://127.0.0.1:6333/readyz || true; echo
wget -qO- http://127.0.0.1:4000/v1/models || true; echo
