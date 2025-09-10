#!/usr/bin/env bash
set -Eeuo pipefail

COMPOSE="/data/stack/ai_gateway/docker-compose.stack.yml"
OVERLAY="/data/stack/ai_gateway/docker-compose.litellm.run.yml"

echo "== Limpeza de container avulso na :4000 (se existir) =="
docker rm -f litellm 2>/dev/null || true

echo "== Recriar serviço litellm com overlay de execução explícita =="
docker compose -f "$COMPOSE" -f "$OVERLAY" up -d --remove-orphans litellm

CID="$(docker compose -f "$COMPOSE" ps -q litellm)"
[ -n "$CID" ] || { echo "ERRO: litellm não encontrado no projeto ai_gateway"; exit 1; }
echo "Container litellm: $CID"

echo "== Esperando porta 4000 ouvir =="
for i in {1..30}; do
  if nc -z 127.0.0.1 4000 2>/dev/null; then echo "OK 4000 aberta"; break; fi
  sleep 1
  if [ "$i" -eq 30 ]; then echo "FALHA: porta 4000 não abriu"; fi
done

echo "== Verificando YAML dentro do container =="
docker exec -i "$CID" sh -lc 'ls -l /config/litellm-config.yaml || true'
docker exec -i "$CID" sh -lc 'head -n 40 /config/litellm-config.yaml || true'

echo "== Processo e sockets no container =="
docker exec -i "$CID" sh -lc 'ps aux | head -n 40'
docker exec -i "$CID" sh -lc 'ss -lnt | sed -n "1,80p"'

echo "== Probes host =="
wget -qO- http://127.0.0.1:4000/v1/models || true; echo
