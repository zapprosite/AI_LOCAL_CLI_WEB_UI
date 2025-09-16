#!/usr/bin/env bash
set -Eeuo pipefail

COMPOSE="/data/stack/ai_gateway/docker-compose.stack.yml"
OVER="/data/stack/ai_gateway/docker-compose.litellm.fix.yml"
CFG="/data/stack/ai_gateway/config/litellm-config.yaml"

echo "== Verificando YAML no host =="
[ -s "$CFG" ] || { echo "ERRO: $CFG ausente ou vazio"; exit 1; }
head -n 40 "$CFG" || true
echo

echo "== Removendo contêiner avulso 'litellm' (se existir) =="
docker rm -f litellm 2>/dev/null || true

echo "== Recriando serviço litellm com entrypoint explícito =="
docker compose -f "$COMPOSE" -f "$OVER" up -d --remove-orphans litellm

CID="$(docker compose -f "$COMPOSE" ps -q litellm || true)"
[ -n "$CID" ] || { echo "ERRO: litellm não encontrado no projeto ai_gateway"; exit 1; }
echo "Container: $CID"

echo "== Aguardando porta :4000 no host =="
for i in {1..30}; do
  if nc -z 127.0.0.1 4000 2>/dev/null; then echo "OK 4000 aberta"; break; fi
  sleep 1
  [ "$i" -eq 30 ] && { echo 'FALHA: porta 4000 não abriu'; docker compose -f "$COMPOSE" logs --no-log-prefix --since=120s litellm || true; exit 1; }
done

echo "== Checagens dentro do container =="
echo "-- YAML montado --"
docker exec -i "$CID" sh -lc 'ls -l /config/litellm-config.yaml && echo "---"; sed -n "1,120p" /config/litellm-config.yaml' || true
echo "-- Processos --"
docker exec -i "$CID" sh -lc 'ps aux | head -n 80' || true
echo "-- Sockets --"
docker exec -i "$CID" sh -lc 'ss -lntp | sed -n "1,120p"' || true
echo "-- Reachability (ollama/qdrant) --"
docker exec -i "$CID" sh -lc 'wget -qO- http://ollama:11434/api/tags | head -c 160' || echo "FAIL: HTTP ollama"
echo
docker exec -i "$CID" sh -lc 'wget -qO- http://qdrant:6333/readyz' || echo "FAIL: HTTP qdrant"
echo

echo "== /v1/models (host) =="
wget -qO- http://127.0.0.1:4000/v1/models || true
echo
