#!/usr/bin/env bash
set -euo pipefail

# bench_hybrid.sh
# Measure latency and tokens for code.hybrid with and without metadata.high_stakes
# Appends CSV rows to /data/stack/_logs/bench_hybrid.csv

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$dir/.." && pwd)"
log_dir="$root/_logs"
csv="$log_dir/bench_hybrid.csv"
mkdir -p "$log_dir"

# Load AUTH
AUTH="${LITELLM_MASTER_KEY:-}"
if [[ -z "$AUTH" && -f "$root/ai_gateway/.env" ]]; then
  set +u; set -a; . "$root/ai_gateway/.env"; set +a; set -u
  AUTH="${LITELLM_MASTER_KEY:-}"
fi
if [[ -z "$AUTH" ]]; then
  echo "ERROR: LITELLM_MASTER_KEY not set or missing ai_gateway/.env" >&2
  exit 1
fi

HDR=(-H "Authorization: Bearer ${AUTH}" -H 'Content-Type: application/json')

now_ms() {
  local t
  t=$(date +%s%3N 2>/dev/null || true)
  if [[ -n "${t:-}" && "$t" =~ ^[0-9]+$ ]]; then printf '%s' "$t"; return; fi
  t=$(date +%s%N 2>/dev/null || true)
  if [[ -n "${t:-}" && "$t" =~ ^[0-9]+$ ]]; then printf '%s' "${t:0:13}"; return; fi
  python3 - <<'PY'
import time; print(int(time.time()*1000))
PY
}

append_csv() {
  local ts model mode lat tokens
  ts="$1"; model="$2"; mode="$3"; lat="$4"; tokens="$5"
  if [[ ! -f "$csv" ]]; then
    echo "ts,model,mode,latency_ms,tokens_out" > "$csv"
  fi
  echo "$ts,$model,$mode,$lat,$tokens" >> "$csv"
}

bench_one() {
  local mode="$1"
  local tmp start end lat model tokens content
  tmp="/tmp/bench_hybrid_${mode}.json"
  # Prompt designed to yield ~16–32 tokens
  local meta
  if [[ "$mode" == high_stakes ]]; then meta='"metadata": {"high_stakes": true},'; else meta=''; fi
  local payload
  payload=$(cat <<JSON
{
  "model": "code.hybrid",
  "messages": [{"role": "user", "content": "Write exactly 25 words summarizing why unit tests matter. Keep words simple."}],
  "temperature": 0.2,
  ${meta}
  "max_tokens": 64
}
JSON
)
  start=$(now_ms)
  http=$(curl -sS "${HDR[@]}" -d "$payload" -o "$tmp" -w '%{http_code}' http://127.0.0.1:4001/v1/chat/completions || echo 000)
  end=$(now_ms)
  lat=$((end-start))
  model=$(jq -r '.model // ""' "$tmp" 2>/dev/null || true)
  tokens=$(jq -r '.usage.completion_tokens // empty' "$tmp" 2>/dev/null || true)
  if [[ -z "${tokens:-}" ]]; then
    content=$(jq -r '.choices[0].message.content // ""' "$tmp" 2>/dev/null || true)
    tokens=$(printf '%s' "$content" | wc -w | tr -d ' ')
  fi
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  append_csv "$ts" "$model" "$mode" "$lat" "$tokens"
  # echo a brief line for immediate feedback
  echo "$mode: http=$http model=$model latency_ms=$lat tokens_out=$tokens"
}

bench_one local
bench_one high_stakes

echo "Appended to: $csv"
