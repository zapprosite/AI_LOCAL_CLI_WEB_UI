#!/usr/bin/env bash
set -Eeuo pipefail

COMPOSE="/data/stack/ai_gateway/docker-compose.litellm.uvicorn.yml"

# 1) Garantir que o serviço está de pé
docker compose -f "$COMPOSE" up -d litellm
CID="$(docker compose -f "$COMPOSE" ps -q litellm || true)"
[ -n "$CID" ] || { echo "ERRO: litellm não está rodando"; exit 1; }

echo "== ENV no container (confirma LITELLM_CONFIG) =="
docker exec -i "$CID" sh -lc 'env | grep -E "^LITELLM_CONFIG=|NO_PROXY|no_proxy" || true'

echo; echo "== Reachability do litellm -> ollama =="
docker exec -i "$CID" sh -lc 'wget -qO- http://ollama:11434/api/tags | head -c 160' || echo "FAIL: HTTP ollama"
echo

# 2) Warm-up: primeira inferência pode levar > 30s; damos 120s aqui
echo "== Warm-up chat direto =="
WGET="wget -q --timeout=120 --tries=1 -O-"
$WGET --header='Content-Type: application/json' \
  --post-data='{"model":"ollama/qwen2.5-coder:14b","messages":[{"role":"user","content":"Return 2+2 as a single number."}],"stream":false,"max_tokens":8}' \
  http://127.0.0.1:4000/v1/chat/completions || true
echo

# 3) Segunda chamada rápida (cache/modelo já carregado)
echo "== Chat direto (2ª chamada, deve responder rápido) =="
$WGET --header='Content-Type: application/json' \
  --post-data='{"model":"ollama/qwen2.5-coder:14b","messages":[{"role":"user","content":"Return 2+2 as a single number."}],"stream":false,"max_tokens":8}' \
  http://127.0.0.1:4000/v1/chat/completions || true
echo

# 4) Models é apenas informativo — mostramos mesmo assim
echo "== /v1/models (pode ser vazio no LiteLLM) =="
$WGET http://127.0.0.1:4000/v1/models || true
echo
