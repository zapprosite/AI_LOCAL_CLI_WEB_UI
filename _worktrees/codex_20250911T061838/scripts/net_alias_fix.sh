#!/usr/bin/env bash
set -euo pipefail
NET=ai_stack_net
docker network create "$NET" >/dev/null 2>&1 || true

# anexar 3 containers à mesma rede
for c in litellm ai_gateway-ollama-1 ai_gateway-qdrant-1; do
  docker network inspect "$NET" -f '{{range .Containers}}{{.Name}}{{"\n"}}{{end}}' \
    | grep -qx "$c" || docker network connect "$NET" "$c"
done

# aliases compatíveis
docker network connect --alias ollama            "$NET" ai_gateway-ollama-1 2>/dev/null || true
docker network connect --alias ai_stack-ollama-1 "$NET" ai_gateway-ollama-1 2>/dev/null || true
docker network connect --alias qdrant            "$NET" ai_gateway-qdrant-1 2>/dev/null || true
docker network connect --alias ai_stack-qdrant-1 "$NET" ai_gateway-qdrant-1 2>/dev/null || true

# inspeção (escapar $ no template)
docker inspect -f '{{.Name}} -> {{range $$k,$$v := .NetworkSettings.Networks}}{{printf "%s " $$k}}{{end}}' litellm
docker inspect -f '{{.Name}} -> {{range $$k,$$v := .NetworkSettings.Networks}}{{printf "%s " $$k}}{{end}}' ai_gateway-ollama-1
docker inspect -f '{{.Name}} -> {{range $$k,$$v := .NetworkSettings.Networks}}{{printf "%s " $$k}}{{end}}' ai_gateway-qdrant-1
