#!/usr/bin/env bash
set -Eeuo pipefail

COMPOSE_MIN="/data/stack/ai_gateway/docker-compose.litellm.min.yml"

echo "== 1/5 Subindo LiteLLM com YAML mínimo =="
docker compose -f "$COMPOSE_MIN" up -d --remove-orphans litellm

CID="$(docker compose -f "$COMPOSE_MIN" ps -q litellm || true)"
[ -n "$CID" ] || { echo "ERRO: litellm não criado"; exit 1; }
echo "Container: $CID"

echo "== 2/5 Aguardando :4000 =="
for i in {1..30}; do
  nc -z 127.0.0.1 4000 2>/dev/null && { echo "OK 4000 aberta"; break; }
  sleep 1
  [ "$i" -eq 30 ] && { echo "FALHA: porta 4000 não abriu"; docker compose -f "$COMPOSE_MIN" logs --since=120s --no-log-prefix litellm || true; exit 1; }
done

echo "== 3/5 Logs recentes (devem imprimir o YAML mínimo) =="
docker compose -f "$COMPOSE_MIN" logs --since=20s --no-log-prefix litellm || true

echo "== 4/5 Processos/Sockets =="
docker exec -i "$CID" sh -lc 'ps aux | head -n 60' || true
docker exec -i "$CID" sh -lc 'ss -lntp 2>/dev/null || netstat -lntp 2>/dev/null || true' | sed -n '1,120p'

echo "== 5/5 /v1/models (host) =="
wget -qO- http://127.0.0.1:4000/v1/models || true
echo
