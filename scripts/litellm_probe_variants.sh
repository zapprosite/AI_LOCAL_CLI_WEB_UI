#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/data/stack/ai_gateway/docker-compose.litellm.base.yml"
VARIANTS=(
  "/data/stack/ai_gateway/docker-compose.litellm.var.python.yml"
  "/data/stack/ai_gateway/docker-compose.litellm.var.cli.yml"
  "/data/stack/ai_gateway/docker-compose.litellm.var.start.yml"
  "/data/stack/ai_gateway/docker-compose.litellm.var.uvicorn.yml"
)

echo "== Garantir rede externa =="
docker network inspect ai_stack_net >/dev/null 2>&1 || docker network create ai_stack_net

for OV in "${VARIANTS[@]}"; do
  echo "== Tentando variante: $OV =="
  docker compose -f "$BASE" -f "$OV" up -d --remove-orphans litellm

  # aguarda porta
  for i in {1..30}; do
    if nc -z 127.0.0.1 4000 2>/dev/null; then echo "OK: porta 4000 aberta"; break; fi
    sleep 1
    if [ "$i" -eq 30 ]; then
      echo "FALHA: porta 4000 não abriu nesta variante"
      docker compose -f "$BASE" logs --since=60s --no-log-prefix litellm || true
      continue 2
    fi
  done

  # consulta /v1/models
  OUT="$(wget -q --timeout=6 -O- http://127.0.0.1:4000/v1/models || true)"
  echo "Resposta /v1/models: ${OUT:0:200}"
  if grep -q 'qwen2.5-coder' <<<"$OUT"; then
    echo "SUCESSO: variante '$OV' carregou modelo do YAML."
    exit 0
  fi

  echo "== Logs recentes (60s) desta variante =="
  docker compose -f "$BASE" logs --since=60s --no-log-prefix litellm || true
  echo "== /v1/models não contém o modelo esperado; testando chat direto mesmo assim =="
  wget -q --timeout=6 --header='Content-Type: application/json' \
    --post-data='{"model":"ollama/qwen2.5-coder:14b","messages":[{"role":"user","content":"Return 2+2 as a single number."}]}' \
    -O- http://127.0.0.1:4000/v1/chat/completions || true
  echo
done

echo "ERRO: nenhuma variante carregou o YAML (modelo não apareceu)."
exit 1
