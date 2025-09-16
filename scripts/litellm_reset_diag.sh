#!/usr/bin/env bash
set -Eeuo pipefail

COMPOSE="/data/stack/ai_gateway/docker-compose.stack.yml"
OVERLAY="/data/stack/ai_gateway/docker-compose.litellm.run.yml"

echo "== 1/4 Derrubar possíveis órfãos que escutem :4000 =="
docker rm -f litellm 2>/dev/null || true

echo "== 2/4 Subir litellm com entrypoint explícito =="
docker compose -f "$COMPOSE" -f "$OVERLAY" up -d --remove-orphans litellm

CID="$(docker compose -f "$COMPOSE" ps -q litellm || true)"
[ -n "$CID" ] || { echo "ERRO: litellm não encontrado no projeto ai_gateway"; exit 1; }
echo "Container: $CID"

echo "== 3/4 Aguardar porta :4000 =="
for i in {1..30}; do
  if nc -z 127.0.0.1 4000 2>/dev/null; then echo "OK 4000 aberta"; break; fi
  sleep 1
  [ "$i" -eq 30 ] && { echo "FALHA: porta 4000 não abriu"; exit 1; }
done

echo "== 4/4 Diagnóstico interno do container =="
echo "-- YAML dentro do container --"
docker exec -i "$CID" sh -lc 'ls -l /config/litellm-config.yaml && echo "---"; sed -n "1,160p" /config/litellm-config.yaml' || true
echo "-- Processos --"
docker exec -i "$CID" sh -lc 'ps aux | head -n 60' || true
echo "-- Sockets --"
docker exec -i "$CID" sh -lc 'ss -lnt | sed -n "1,80p"' || true
echo "-- /v1/models (host) --"
wget -S -qO- http://127.0.0.1:4000/v1/models 2>&1 | sed -n '1,120p' || true
