#!/usr/bin/env bash
set -euo pipefail
NET=ai_stack_net
docker network create "$NET" 2>/dev/null || true
for c in litellm ai_stack-ollama-1 ai_stack-qdrant-1; do
  docker network inspect "$NET" -f '{{range .Containers}}{{.Name}}{{"\n"}}{{end}}' \
    | grep -qx "$c" || docker network connect "$NET" "$c"
done
docker network inspect "$NET" -f 'net={{.Name}} members={{range .Containers}}{{.Name}} {{end}}'
