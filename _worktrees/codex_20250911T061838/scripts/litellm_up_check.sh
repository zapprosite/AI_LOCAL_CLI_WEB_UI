#!/usr/bin/env bash
set -Eeuo pipefail

COMPOSE="/data/stack/ai_gateway/docker-compose.stack.yml"
OVERLAY="/data/stack/ai_gateway/docker-compose.litellm.run.yml"

echo "== Recriando litellm com entrypoint explícito =="
docker compose -f "$COMPOSE" -f "$OVERLAY" up -d --remove-orphans litellm

CID="$(docker compose -f "$COMPOSE" ps -q litellm || true)"
[ -n "$CID" ] || { echo "ERRO: litellm não encontrado no projeto ai_gateway"; exit 1; }

echo "== Aguardando porta :4000 ouvir =="
for i in {1..30}; do
  if nc -z 127.0.0.1 4000 2>/dev/null; then echo "OK 4000 aberta"; break; fi
  sleep 1
  [ "$i" -eq 30 ] && { echo "FALHA: porta 4000 não abriu"; exit 1; }
done

echo "== DNS interno no litellm =="
docker exec -i "$CID" getent hosts ollama || echo "FAIL: DNS ollama"
docker exec -i "$CID" getent hosts qdrant || echo "FAIL: DNS qdrant"

echo "== YAML montado no container =="
docker exec -i "$CID" sh -lc 'ls -l /config/litellm-config.yaml && echo "---" && sed -n "1,120p" /config/litellm-config.yaml' || true

echo "== /v1/models (host) =="
wget -qO- http://127.0.0.1:4000/v1/models || true
echo
