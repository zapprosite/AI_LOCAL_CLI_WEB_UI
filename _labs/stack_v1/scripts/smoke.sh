#!/usr/bin/env bash
set -euo pipefail
BASE="${OPENAI_BASE_URL:-http://127.0.0.1:4000}"
echo "== /v1/models =="; curl -sfS "$BASE/v1/models" | head -c 400 || true; echo
echo "== LITELLM /health =="; curl -sfS "$BASE/health" || true; echo
