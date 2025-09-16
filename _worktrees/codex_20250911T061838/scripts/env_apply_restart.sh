#!/usr/bin/env bash
set -Eeuo pipefail

GWD="/data/stack/ai_gateway"
ENVF="${GWD}/.env"
BASE="${GWD}/docker-compose.stack.yml"
OVLY="${GWD}/docker-compose.env.overlay.yml"

echo "== 1/4 Validando .env e overlays =="
[ -s "$ENVF" ] || { echo "ERRO: $ENVF ausente/vazio"; exit 1; }
[ -s "$BASE" ] || { echo "ERRO: compose base ausente"; exit 1; }
[ -s "$OVLY" ] || { echo "ERRO: overlay ausente"; exit 1; }

echo "== 2/4 Compose config (expansão de vars) =="
docker compose --env-file "$ENVF" -f "$BASE" -f "$OVLY" config | sed -n '1,80p' || true
echo

echo "== 3/4 Subindo stack com .env (idempotente) =="
cd "$GWD"
docker compose --env-file "$ENVF" -f "$BASE" -f "$OVLY" up -d --remove-orphans
docker compose --env-file "$ENVF" -f "$BASE" -f "$OVLY" ps

echo "== 4/4 Checagem rápida de portas =="
for p in "${OLLAMA_PORT:-11434}" "${LITELLM_PORT:-4000}" "${QDRANT_PORT:-6333}" "${OPENWEBUI_PORT:-3000}"; do
  nc -z 127.0.0.1 "$p" && echo "PORT OK $p" || echo "PORT FAIL $p"
done
