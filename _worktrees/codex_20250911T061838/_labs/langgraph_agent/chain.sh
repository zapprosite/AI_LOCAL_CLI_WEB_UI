#!/bin/sh
set -euo pipefail 2>/dev/null || set -eu
LITELLM_URL="${LITELLM_URL:-http://127.0.0.1:4000}"
LOG_FILE=/var/log/ai_stack/router.log
mode=${1:-chat}
shift 2>/dev/null || true
file=""; max_tokens=1024; temperature=0.2; dry=0
while [ $# -gt 0 ]; do
  case "$1" in
    --file) file=${2:-}; shift 2;;
    --max-tokens) max_tokens=${2:-1024}; shift 2;;
    --temperature) temperature=${2:-0.2}; shift 2;;
    --dry-run) dry=1; shift;;
    *) shift;;
  esac
done
case "$mode" in
  chat) local_route=local-chat;;
  parse) local_route=local-qwen-coder;;
  code) local_route=local-deepseek-c2;;
  refactor) local_route=local-qwen-coder;;
  *) echo "unknown mode: $mode" >&2; exit 2;;
esac
[ -n "$file" ] && [ -f "$file" ] && prompt=$(cat "$file") || prompt=$(cat || true)
[ -n "${prompt:-}" ] || { echo "empty prompt" >&2; exit 3; }
jescape() { printf %s "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e ':a;N;$!ba;s/\n/\\n/g'; }
TOKENS_EST=$(( ( $(printf %s "$prompt" | wc -c) + 3 ) / 4 ))
call_api() {
  route="$1"; body="$2"; start=$(date +%s%3N 2>/dev/null || date +%s000)
  auth=""; [ -n "${OPENAI_API_KEY:-}" ] && auth="-H Authorization: Bearer ${OPENAI_API_KEY}"
  http=$(curl -sS -m 30 -H 'Content-Type: application/json' $auth -o /tmp/resp_$$ -w '%{http_code}' -d "$body" "$LITELLM_URL/v1/chat/completions" || echo 000)
  end=$(date +%s%3N 2>/dev/null || date +%s000); lat=$((end-start))
  if [ "$http" -ge 200 ] 2>/dev/null && [ "$http" -lt 300 ] 2>/dev/null; then ok=1; else ok=0; fi
  echo "$http" "$lat" "$ok"
}
mkjson() {
  r="$1"; jp=$(jescape "$prompt")
  printf '{"model":"%s","max_tokens":%s,"temperature":%s,"messages":[{"role":"user","content":"%s"}]}' "$r" "$max_tokens" "$temperature" "$jp"
}
local_attempts=0; fallback=none; used="$local_route"; json=""; status=0; http=0; lat=0
if [ "$TOKENS_EST" -gt 6000 ]; then used=remote-o3; fallback=remote-o3; json=$(mkjson "$used"); set -- $(call_api "$used" "$json"); http=$1; lat=$2; ok=$3
  if [ "$ok" -ne 1 ]; then used=remote-o3-pro; fallback=remote-o3-pro; json=$(mkjson "$used"); set -- $(call_api "$used" "$json"); http=$1; lat=$2; ok=$3; fi
else
  json=$(mkjson "$local_route"); set -- $(call_api "$local_route" "$json"); http=$1; lat=$2; ok=$3; local_attempts=1
  if [ "$ok" -ne 1 ]; then set -- $(call_api "$local_route" "$json"); http=$1; lat=$2; ok=$3; local_attempts=2; fi
  if [ "$ok" -ne 1 ]; then used=remote-o3; fallback=remote-o3; json=$(mkjson "$used"); set -- $(call_api "$used" "$json"); http=$1; lat=$2; ok=$3; fi
  if [ "$ok" -ne 1 ]; then used=remote-o3-pro; fallback=remote-o3-pro; json=$(mkjson "$used"); set -- $(call_api "$used" "$json"); http=$1; lat=$2; ok=$3; fi
fi
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
printf 'MODE=%s LOCAL=%s FALLBACK=%s LAT=%s OK=%s\n' "$mode" "$local_route" "$fallback" "$lat" "$ok" >> "$LOG_FILE" 2>/dev/null || true
if [ "$dry" -eq 1 ]; then echo "$json"; exit 0; fi
cat /tmp/resp_$$
[ "$ok" -eq 1 ]
