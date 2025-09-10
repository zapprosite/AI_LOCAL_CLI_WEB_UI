#!/usr/bin/env bash
set -Eeuo pipefail

COMPOSE="/data/stack/ai_gateway/docker-compose.stack.yml"
OVERLAY="/data/stack/ai_gateway/docker-compose.litellm.force.yml"

echo "== Recriando litellm com entrypoint explícito =="
docker rm -f litellm 2>/dev/null || true
docker compose -f "$COMPOSE" -f "$OVERLAY" up -d --remove-orphans litellm

CID="$(docker compose -f "$COMPOSE" ps -q litellm || true)"
[ -n "$CID" ] || { echo "ERRO: litellm não encontrado no projeto ai_gateway"; exit 1; }
echo "Container: $CID"

echo "== Aguardando porta :4000 no host =="
for i in {1..30}; do
  if nc -z 127.0.0.1 4000 2>/dev/null; then echo "OK 4000 aberta"; break; fi
  sleep 1
  [ "$i" -eq 30 ] && { echo "FALHA: porta 4000 não abriu"; exit 1; }
done

echo "== YAML montado no container =="
docker exec -i "$CID" sh -lc 'ls -l /config/litellm-config.yaml && echo "---"; sed -n "1,160p" /config/litellm-config.yaml' || true

echo "== DNS/Reachability a partir do litellm =="
docker exec -i "$CID" getent hosts ollama || echo "FAIL: DNS ollama"
docker exec -i "$CID" getent hosts qdrant || echo "FAIL: DNS qdrant"
docker exec -i "$CID" sh -lc 'wget -qO- http://ollama:11434/api/tags | head -c 160' || echo "FAIL: HTTP ollama"
echo
docker exec -i "$CID" sh -lc 'wget -qO- http://qdrant:6333/readyz' || echo "FAIL: HTTP qdrant"
echo

echo "== Processos e sockets no container =="
docker exec -i "$CID" sh -lc 'ps aux | head -n 80' || true
docker exec -i "$CID" sh -lc 'ss -lnt | sed -n "1,120p"' || true

echo "== Host -> /v1/models (com headers) =="
wget -S -O- http://127.0.0.1:4000/v1/models 2>&1 | sed -n '1,120p' || true
