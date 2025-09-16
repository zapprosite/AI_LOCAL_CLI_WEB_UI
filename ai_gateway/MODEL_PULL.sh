#!/usr/bin/env bash
set -euo pipefail

# Pull a curated set of Ollama models (idempotent)
# Models: qwen2.5-coder:14b, qwen2.5:7b-instruct, llama3.1:8b-instruct, bge-small
# Requires: ollama CLI on PATH; daemon reachable

if ! command -v ollama >/dev/null 2>&1; then
  echo "error: 'ollama' not found in PATH" >&2
  exit 1
fi

has_model() {
  local name="$1"
  local names
  if names="$(ollama list 2>/dev/null | awk 'NR>1{print $1}')" && \
     printf '%s\n' "$names" | grep -Fxq -- "$name"; then
    return 0
  fi
  return 1
}

ensure_model() {
  local name="$1"
  if has_model "$name"; then
    echo "[skip] $name already present"
  else
    echo "[pull] $name"
    ollama pull "$name"
  fi
}

models=(
  "qwen2.5-coder:14b"
  "qwen2.5:7b-instruct"
  "llama3.1:8b-instruct"
  "bge-small"
)

for m in "${models[@]}"; do
  ensure_model "$m"
done

echo "[done] Current local models:"
ollama list

