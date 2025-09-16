#!/usr/bin/env sh
set -eu
LITE="${LITE:-http://127.0.0.1:4000}"
OLLA="${OLLA:-http://127.0.0.1:11434}"

# carrega .env se existir
[ -f /data/stack/ai_gateway/.env ] && . /data/stack/ai_gateway/.env || true

# AUTH = token se existir; usa expansão ${AUTH:+-H} ${AUTH:+"Authorization: Bearer $AUTH"}
AUTH=""
[ -n "${LITELLM_MASTER_KEY:-}" ]  && AUTH="$LITELLM_MASTER_KEY"
[ -z "$AUTH" ] && [ -n "${LITELLM_PROXY_SECRET:-}" ] && AUTH="$LITELLM_PROXY_SECRET"

need() { command -v "$1" >/dev/null 2>&1 || { echo "MISSING:$1"; exit 1; }; }
need curl; need jq

echo "== LiteLLM /v1/models =="
curl -sS ${AUTH:+-H} ${AUTH:+"Authorization: Bearer $AUTH"} "${LITE}/v1/models" \
| tee /tmp/models.json | jq -r '.data[]?.id' || true

echo "== Chat completions via LiteLLM (aliases fast|light|heavy) =="
for M in fast light heavy; do
  printf "\n-- model:%s --\n" "$M"
  RES="$(curl -sS -X POST "${LITE}/v1/chat/completions" \
     -H "Content-Type: application/json" \
     ${AUTH:+-H} ${AUTH:+"Authorization: Bearer $AUTH"} \
     -d "{\"model\":\"$M\",\"messages\":[{\"role\":\"user\",\"content\":\"Return only the sum 2+2 as a number.\"}],\"temperature\":0}")" || true
  echo "$RES" | jq -r '.choices[0].message.content' | sed '/^null$/d' | sed 's/^/ANS: /' || true
  echo "$RES" | jq -r '.error | objects | .message'       | sed '/^null$/d' | sed 's/^/ERR: /' || true
done

echo "== Direct Ollama chat (qwen2.5-coder:14b) =="
REQ='{"model":"qwen2.5-coder:14b","messages":[{"role":"user","content":"Say OK"}],"stream":false}'
curl -sS -X POST "${OLLA}/api/chat" -H "Content-Type: application/json" -d "$REQ" \
| jq -r '.message.content // empty'
