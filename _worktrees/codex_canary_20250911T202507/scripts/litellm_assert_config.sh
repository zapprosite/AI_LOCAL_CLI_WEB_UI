#!/usr/bin/env bash
set -Eeuo pipefail

COMPOSE="/data/stack/ai_gateway/docker-compose.litellm.uvicorn.yml"

CID="$(docker compose -f "$COMPOSE" ps -q litellm || true)"
[ -n "$CID" ] || { echo "ERRO: container litellm não encontrado (suba com litellm_uvicorn_boot.sh)"; exit 1; }

echo "== ENV dentro do contêiner (LITELLM_CONFIG/NO_PROXY) =="
docker exec -i "$CID" sh -lc 'env | grep -E "LITELLM_CONFIG|NO_PROXY|no_proxy" || true'

echo; echo "== Verificar arquivo de config montado =="
docker exec -i "$CID" sh -lc 'ls -l /config/litellm-config.yaml && echo "---"; sed -n "1,120p" /config/litellm-config.yaml'

echo; echo "== Versão/bins disponíveis =="
docker exec -i "$CID" sh -lc 'python -V; python -c "import litellm,sys;print(\"litellm:\", getattr(litellm, \"__version__\", \"?\"))" || true'
docker exec -i "$CID" sh -lc 'command -v uvicorn && uvicorn --version || true'

echo; echo "== Processos e sockets (espera LISTEN :4000) =="
docker exec -i "$CID" sh -lc 'ps aux | head -n 80'
docker exec -i "$CID" sh -lc 'ss -lntp 2>/dev/null || netstat -lntp 2>/dev/null || true' | sed -n '1,160p'

echo; echo "== /v1/models (via host) =="
wget -qO- http://127.0.0.1:4000/v1/models || true
echo
