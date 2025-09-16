#!/usr/bin/env bash
set -Eeuo pipefail

COMPOSE="/data/stack/ai_gateway/docker-compose.litellm.uvicorn.yml"
TEST="/data/stack/ai_gateway/scripts/stack_chat_tests_v1.sh"

echo "== 0/3 Pré-checagens =="
[ -s "$COMPOSE" ] || { echo "ERRO: $COMPOSE ausente"; exit 1; }
[ -s "$TEST" ] || { echo "ERRO: $TEST ausente"; exit 1; }

echo "== 1/3 Subindo LiteLLM (uvicorn) =="
docker compose -f "$COMPOSE" up -d --remove-orphans litellm
for i in {1..40}; do
  nc -z 127.0.0.1 4000 2>/dev/null && { echo "OK porta 4000"; break; }
  sleep 1
  [ "$i" -eq 40 ] && { echo "FALHA: 4000 não abriu"; docker compose -f "$COMPOSE" logs --since=120s --no-log-prefix litellm || true; exit 1; }
done

echo "== 2/3 Rodando testes de chat =="
chmod +x "$TEST"
"$TEST"

echo "== 3/3 Dica de uso =="
echo "Ex.: TIMEOUT_FIRST=180 MODEL_DIRECT='ollama/qwen2.5-coder:14b' $TEST"
