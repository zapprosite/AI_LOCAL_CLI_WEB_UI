#!/usr/bin/env bash
set -Eeuo pipefail

COMPOSE_ONLY="/data/stack/ai_gateway/docker-compose.litellm.only.yml"
CFG="/data/stack/ai_gateway/config/litellm-config.yaml"

echo "== Verificando YAML no host =="
[ -s "$CFG" ] || { echo "ERRO: $CFG ausente ou vazio"; exit 1; }
head -n 60 "$CFG" || true
echo

echo "== Subindo apenas o litellm (projeto ai_gateway) =="
# Importante: sem --remove-orphans para não derrubar ollama/qdrant/openwebui
docker compose -f "$COMPOSE_ONLY" up -d litellm

CID="$(docker compose -f "$COMPOSE_ONLY" ps -q litellm || true)"
[ -n "$CID" ] || { echo "ERRO: container litellm não criado"; exit 1; }
echo "Container: $CID"

echo "== Aguardando porta :4000 no host =="
for i in {1..30}; do
  if nc -z 127.0.0.1 4000 2>/dev/null; then echo "OK 4000 aberta"; break; fi
  sleep 1
  if [ "$i" -eq 30 ]; then
    echo "FALHA: porta 4000 não abriu. Logs (120s):"
    docker compose -f "$COMPOSE_ONLY" logs --no-log-prefix --since=120s litellm || true
    exit 1
  fi
done

echo "== Diagnóstico interno =="
echo "-- YAML montado --"
docker exec -i "$CID" sh -lc 'ls -l /config/litellm-config.yaml && echo "---"; sed -n "1,160p" /config/litellm-config.yaml' || true
echo "-- Binário litellm --"
docker exec -i "$CID" sh -lc 'command -v litellm && litellm --version || true'
echo "-- Processos --"
docker exec -i "$CID" sh -lc 'ps aux | head -n 80' || true
echo "-- Sockets (esperado LISTEN :4000) --"
docker exec -i "$CID" sh -lc 'ss -lntp 2>/dev/null || netstat -lntp 2>/dev/null || true' | sed -n '1,160p'
echo "-- DNS/Reachability (ollama/qdrant) --"
docker exec -i "$CID" getent hosts ollama || echo "FAIL: DNS ollama"
docker exec -i "$CID" getent hosts qdrant || echo "FAIL: DNS qdrant"
docker exec -i "$CID" sh -lc 'wget -qO- http://ollama:11434/api/tags | head -c 160' || echo "FAIL: HTTP ollama"
echo
docker exec -i "$CID" sh -lc 'wget -qO- http://qdrant:6333/readyz' || echo "FAIL: HTTP qdrant"
echo

echo "== /v1/models (host) =="
wget -S -O- http://127.0.0.1:4000/v1/models 2>&1 | sed -n '1,200p' || true
