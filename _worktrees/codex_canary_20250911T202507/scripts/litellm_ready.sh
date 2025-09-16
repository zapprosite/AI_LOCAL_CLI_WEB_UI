#!/usr/bin/env bash
set -Eeuo pipefail

COMPOSE="/data/stack/ai_gateway/docker-compose.stack.yml"
OVERLAY="/data/stack/ai_gateway/docker-compose.litellm.cmd.yml"

# Sobe só o litellm com overlay (idempotente)
docker compose -f "$COMPOSE" -f "$OVERLAY" up -d --remove-orphans litellm

CID="$(docker compose -f "$COMPOSE" ps -q litellm || true)"
[ -n "$CID" ] || { echo "ERRO: litellm não encontrado no projeto ai_gateway"; exit 1; }

# Aguarda porta 4000 e que /v1/models retorne algo não-vazio
echo "Aguardando :4000 ouvir..."
for i in {1..30}; do
  if nc -z 127.0.0.1 4000 2>/dev/null; then echo "OK 4000 aberta"; break; fi
  sleep 1
  [ "$i" -eq 30 ] && { echo "FALHA: porta 4000 não abriu"; exit 1; }
done

echo "Aguardando /v1/models com dados..."
for i in {1..20}; do
  OUT="$(wget -qO- http://127.0.0.1:4000/v1/models || true)"
  if [ -n "$OUT" ] && ! grep -q '"data":\[\]' <<<"$OUT"; then
    echo "$OUT"
    exit 0
  fi
  sleep 1
done

echo "Models vazio. Logs recentes do litellm:"
docker compose -f "$COMPOSE" logs --since=60s --no-log-prefix litellm || true
exit 1
