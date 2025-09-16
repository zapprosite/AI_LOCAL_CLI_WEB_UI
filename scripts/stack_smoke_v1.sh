#!/usr/bin/env bash
set -euo pipefail
BASE=${OPENAI_BASE_URL:-http://127.0.0.1:4000}
echo "== endpoints =="; curl -sfS 127.0.0.1:11434/api/tags | head -c 80; echo
curl -sfS 127.0.0.1:6333/readyz || true; echo
curl -sfS "$BASE/v1/models" | jq -r '.data[].id' 2>/dev/null || curl -sfS "$BASE/v1/models"; echo
echo "== code =="; curl -sS "$BASE/v1/chat/completions" -H 'content-type: application/json' \
 -d '{"model":"task:code-router","messages":[{"role":"user","content":"one-liner bash para listar GPUs NVIDIA"}]}' | head -c 300; echo
echo "== docs =="; curl -sS "$BASE/v1/chat/completions" -H 'content-type: application/json' \
 -d '{"model":"task:docs-router","messages":[{"role":"user","content":"Resumo curto: versionar PRDs e DOCs?"}]}' | head -c 300; echo
