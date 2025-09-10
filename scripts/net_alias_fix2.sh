#!/usr/bin/env bash
set -Eeuo pipefail
NET=ai_stack_net
docker network inspect "$NET" >/dev/null 2>&1 || docker network create "$NET"

ensure_conn() {
  local name="$1"; shift
  # já conectado?
  if docker network inspect "$NET" | grep -q "\"Name\": \"$name\""; then return 0; fi
  docker network connect "$NET" "$name" "$@" || true
}

# conectar serviços e aliases
docker ps --format '{{.Names}}' | grep -qx ai_gateway-ollama-1  && ensure_conn ai_gateway-ollama-1 --alias ollama
docker ps --format '{{.Names}}' | grep -qx ai_gateway-qdrant-1  && ensure_conn ai_gateway-qdrant-1 --alias qdrant
docker ps --format '{{.Names}}' | grep -qx litellm               && ensure_conn litellm

echo "OK network $NET"
