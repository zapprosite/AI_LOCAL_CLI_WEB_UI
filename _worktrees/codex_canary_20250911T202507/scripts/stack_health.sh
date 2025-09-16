#!/usr/bin/env bash
set -euo pipefail
echo "=== DOCKER ==="
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}' | grep -E '(^litellm$|ai_stack-(ollama|qdrant|openwebui)-1|^NAMES)' || true
echo "=== NETWORKS ==="
for c in litellm ai_stack-ollama-1 ai_stack-qdrant-1; do
  docker inspect -f '{{.Name}} -> {{range $$k,$$v := .NetworkSettings.Networks}}{{printf "%s " $$k}}{{end}}' "$c" 2>/dev/null || true
done
echo "=== ENDPOINTS (host) ==="
curl -sfS 127.0.0.1:11434/api/tags | head -c 160 || echo "ollama FAIL"; echo
curl -sfS 127.0.0.1:6333/readyz || curl -sfS 127.0.0.1:6333/livez || echo "qdrant FAIL"; echo
curl -sfS 127.0.0.1:4000/v1/models | head -c 400 || echo "litellm FAIL"; echo
echo "=== IN-CONTAINER (litellm) ==="
docker exec -i litellm sh -lc 'getent hosts ollama || echo no-dns; getent hosts qdrant || echo no-dns' || true
