#!/usr/bin/env bash
set -Eeuo pipefail

COMPOSE="/data/stack/ai_gateway/docker-compose.stack.yml"
OVERLAY="/data/stack/ai_gateway/docker-compose.litellm.run.yml"

# Sobe (ou recria) apenas litellm com o overlay
docker compose -f "$COMPOSE" -f "$OVERLAY" up -d --remove-orphans litellm

CID="$(docker compose -f "$COMPOSE" ps -q litellm || true)"
[ -n "$CID" ] || { echo "ERRO: litellm não encontrado"; exit 1; }

echo "== DNS dentro do litellm =="
docker exec -i "$CID" getent hosts ollama || echo "FAIL: DNS ollama"
docker exec -i "$CID" getent hosts qdrant || echo "FAIL: DNS qdrant"

echo; echo "== YAML montado =="
docker exec -i "$CID" sh -lc 'ls -l /config/litellm-config.yaml && echo "---" && sed -n "1,120p" /config/litellm-config.yaml' || true

echo; echo "== Reachability de serviços a partir do litellm =="
docker exec -i "$CID" sh -lc 'wget -qO- http://ollama:11434/api/tags | head -c 160' || echo "FAIL: HTTP ollama"
echo
docker exec -i "$CID" sh -lc 'wget -qO- http://qdrant:6333/readyz' || echo "FAIL: HTTP qdrant"
echo

echo "== Host -> /v1/models =="
wget -qO- http://127.0.0.1:4000/v1/models || true
echo

echo "== Chat direto por modelo (sem router) =="
wget -qO- \
  --header='Content-Type: application/json' \
  --post-data='{"model":"ollama/qwen2.5-coder:14b","messages":[{"role":"user","content":"Return 2+2 as a single number."}],"stream":false,"max_tokens":8}' \
  http://127.0.0.1:4000/v1/chat/completions || true
echo

echo "== Chat via router (task:code-router) =="
wget -qO- \
  --header='Content-Type: application/json' \
  --post-data='{"model":"task:code-router","messages":[{"role":"user","content":"Return 2+2 as a single number."}],"stream":false,"max_tokens":8}' \
  http://127.0.0.1:4000/v1/chat/completions || true
echo
