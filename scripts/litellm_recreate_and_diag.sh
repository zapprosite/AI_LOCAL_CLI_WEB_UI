#!/usr/bin/env bash
set -Eeuo pipefail

COMPOSE_BASE="/data/stack/ai_gateway/docker-compose.stack.yml"
COMPOSE_OVLY="/data/stack/ai_gateway/docker-compose.litellm.override.yml"
CFG="/data/stack/ai_gateway/config/litellm-config.yaml"

echo "== 1/7 Verificando YAML no host =="
[ -s "$CFG" ] || { echo "ERRO: $CFG ausente ou vazio"; exit 1; }
head -n 60 "$CFG" || true
echo

echo "== 2/7 Removendo container avulso 'litellm' (se existir) =="
docker rm -f litellm 2>/dev/null || true

echo "== 3/7 Subindo litellm com entrypoint explícito (--config) =="
docker compose -f "$COMPOSE_BASE" -f "$COMPOSE_OVLY" up -d --remove-orphans litellm

CID="$(docker compose -f "$COMPOSE_BASE" ps -q litellm || true)"
[ -n "$CID" ] || { echo "ERRO: litellm não encontrado no projeto ai_gateway"; exit 1; }
echo "Container: $CID"

echo "== 4/7 Aguardando porta :4000 no host =="
for i in {1..30}; do
  if nc -z 127.0.0.1 4000 2>/dev/null; then echo "OK 4000 aberta"; break; fi
  sleep 1
  if [ "$i" -eq 30 ]; then
    echo "FALHA: porta 4000 não abriu. Logs (120s):"
    docker compose -f "$COMPOSE_BASE" logs --no-log-prefix --since=120s litellm || true
    exit 1
  fi
done

echo "== 5/7 Diagnóstico interno do container =="
echo "-- YAML montado --"
docker exec -i "$CID" sh -lc 'ls -l /config/litellm-config.yaml && echo "---"; sed -n "1,160p" /config/litellm-config.yaml' || true
echo "-- Binário litellm --"
docker exec -i "$CID" sh -lc 'command -v litellm && litellm --version || true'
echo "-- Processos --"
docker exec -i "$CID" sh -lc 'ps aux | head -n 80' || true
echo "-- Sockets (esperado LISTEN :4000) --"
docker exec -i "$CID" sh -lc 'ss -lntp 2>/dev/null || netstat -lntp 2>/dev/null || true' | sed -n '1,160p'

echo "== 6/7 Reachability a partir do litellm =="
docker exec -i "$CID" getent hosts ollama || echo "FAIL: DNS ollama"
docker exec -i "$CID" getent hosts qdrant || echo "FAIL: DNS qdrant"
docker exec -i "$CID" sh -lc 'wget -qO- http://ollama:11434/api/tags | head -c 160' || echo "FAIL: HTTP ollama"
echo
docker exec -i "$CID" sh -lc 'wget -qO- http://qdrant:6333/readyz' || echo "FAIL: HTTP qdrant"
echo

echo "== 7/7 /v1/models (host) =="
wget -S -O- http://127.0.0.1:4000/v1/models 2>&1 | sed -n '1,160p' || true
