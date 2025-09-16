#!/usr/bin/env bash
set -euo pipefail

# SMOKE_HYBRID: Validate hybrid router behavior on :4001
# - Verifies /v1/models contains code.hybrid
# - Deterministic local call (expect content=4)
# - Stops ollama, calls with metadata.high_stakes=true (expect openai/* model)
# - Starts ollama again
# - Writes PASS/FAIL summary to /data/stack/_logs/smoke_hybrid.txt

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$dir/.." && pwd)"
log_dir="$root/_logs"
out="$log_dir/smoke_hybrid.txt"
mkdir -p "$log_dir"

# Load AUTH
AUTH="${LITELLM_MASTER_KEY:-}"
if [[ -z "$AUTH" && -f "$root/ai_gateway/.env" ]]; then
  set +u; set -a; . "$root/ai_gateway/.env"; set +a; set -u
  AUTH="${LITELLM_MASTER_KEY:-}"
fi
if [[ -z "$AUTH" ]]; then
  echo "ERROR: LITELLM_MASTER_KEY not set or missing ai_gateway/.env" | tee "$out" >&2
  exit 1
fi

HDR=(-H "Authorization: Bearer ${AUTH}")

fail=0
note() { printf '%s\n' "$*"; }

# Check models
models_ok=0
http_models=$(curl -sS "${HDR[@]}" -o /tmp/models_4001.json -w '%{http_code}' http://127.0.0.1:4001/v1/models || echo 000)
if [[ "$http_models" != 200 ]]; then
  note "FAIL: /v1/models HTTP=${http_models}"; fail=$((fail+1))
else
  if jq -r '.data[].id' /tmp/models_4001.json 2>/dev/null | grep -qx 'code.hybrid'; then
    note "PASS: /v1/models has code.hybrid"; models_ok=1
  else
    note "FAIL: code.hybrid not listed in /v1/models"; fail=$((fail+1))
  fi
fi

# Deterministic local call
req_local=/tmp/smoke_h_req_local.json
cat >"$req_local" <<'JSON'
{
  "model": "code.hybrid",
  "messages": [{"role": "user", "content": "2+2? answer with a single digit"}],
  "temperature": 0
}
JSON
http_local=$(curl -sS "${HDR[@]}" -H 'Content-Type: application/json' \
  -d @"$req_local" -o /tmp/smoke_h_resp_local.json -w '%{http_code}' \
  http://127.0.0.1:4001/v1/chat/completions || echo 000)
model_local=$(jq -r '.model // ""' /tmp/smoke_h_resp_local.json 2>/dev/null || true)
content_local=$(jq -r '.choices[0].message.content // ""' /tmp/smoke_h_resp_local.json 2>/dev/null || true)
if [[ "$http_local" == 200 && "$content_local" == 4 && "$model_local" == ollama/qwen2.5-coder:* || "$model_local" == ollama/qwen2.5-coder:* ]]; then
  note "PASS: local deterministic (model=${model_local}, content=${content_local})"
else
  # Fallback check for model prefix (portable glob not in bash - use case-insensitive grep)
  if [[ "$http_local" == 200 ]] && printf '%s' "$content_local" | grep -qx '4' \
     && printf '%s' "$model_local" | grep -qi '^ollama/qwen2\.5-coder'; then
    note "PASS: local deterministic (model=${model_local}, content=${content_local})"
  else
    note "FAIL: local deterministic (HTTP=${http_local}, model=${model_local}, content=${content_local})"; fail=$((fail+1))
  fi
fi

# Stop ollama to simulate local failure
if docker ps --format '{{.Names}}' | grep -qx 'ai_gateway-ollama-1'; then
  docker stop ai_gateway-ollama-1 >/dev/null || true
  sleep 3
else
  note "WARN: ai_gateway-ollama-1 not running before stop"
fi

# Fallback attempt with high_stakes
req_fb=/tmp/smoke_h_req_fb.json
cat >"$req_fb" <<'JSON'
{
  "model": "code.hybrid",
  "messages": [{"role": "user", "content": "reply: OK"}],
  "temperature": 0,
  "metadata": {"high_stakes": true}
}
JSON
http_fb=$(curl -sS "${HDR[@]}" -H 'Content-Type: application/json' \
  -d @"$req_fb" -o /tmp/smoke_h_resp_fb.json -w '%{http_code}' \
  http://127.0.0.1:4001/v1/chat/completions || echo 000)
model_fb=$(jq -r '.model // ""' /tmp/smoke_h_resp_fb.json 2>/dev/null || true)
content_fb=$(jq -r '.choices[0].message.content // ""' /tmp/smoke_h_resp_fb.json 2>/dev/null || true)
if [[ "$http_fb" == 200 ]] && printf '%s' "$model_fb" | grep -qi '^openai/'; then
  note "PASS: fallback engaged (model=${model_fb}, content=$(printf '%s' "$content_fb" | tr '\n' ' ' | sed 's/  */ /g' | head -c 60))"
else
  note "FAIL: fallback (HTTP=${http_fb}, model=${model_fb})"; fail=$((fail+1))
fi

# Start ollama again
if docker ps -a --format '{{.Names}}' | grep -qx 'ai_gateway-ollama-1'; then
  docker start ai_gateway-ollama-1 >/dev/null || true
  sleep 5
else
  note "WARN: ai_gateway-ollama-1 not found for start"
fi

# Final summary
if [[ "$fail" -eq 0 ]]; then
  printf 'RESULT: PASS\n' | tee "$out"
  exit 0
else
  printf 'RESULT: FAIL (%d)\n' "$fail" | tee "$out" >&2
  exit 1
fi

