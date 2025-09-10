#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/data/stack"
GWD="/data/stack/ai_gateway"
ENV_FILE="${GWD}/.env"
COMPOSE_FILE="${GWD}/docker-compose.stack.yml"

echo "== 1/5 Verificando .env existente =="
[ -s "${ENV_FILE}" ] || { echo "ERRO: ${ENV_FILE} ausente ou vazio"; exit 1; }
grep -v '^OPENAI_API_KEY=' "${ENV_FILE}" | sed -n '1,80p' || true
echo

echo "== 2/5 Validação do Compose com .env =="
docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" config | sed -n '1,80p' || true
echo

echo "== 3/5 Checando que .env está ignorado no Git =="
cd "${ROOT}"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "WARN: ${ROOT} não é repo Git"; exit 0; }
git check-ignore -v ai_gateway/.env || echo "WARN: .env não está ignorado (verifique .gitignore)"
echo

echo "== 4/5 Ensaios de variáveis críticas =="
awk -F= '/^(COMPOSE_PROJECT_NAME|AI_STACK_NET|OLLAMA_BASE_URL|QDRANT_URL|LITELLM_CONFIG|NO_PROXY|no_proxy)=/ {print "OK " $1 "=" $2}' "${ENV_FILE}" || true
echo

echo "== 5/5 Sanidade leve =="
for p in "${OLLAMA_PORT:-11434}" "${LITELLM_PORT:-4000}" "${QDRANT_PORT:-6333}" "${OPENWEBUI_PORT:-3000}"; do
  nc -z 127.0.0.1 "$p" && echo "PORT OK $p" || echo "PORT FAIL $p"
done
