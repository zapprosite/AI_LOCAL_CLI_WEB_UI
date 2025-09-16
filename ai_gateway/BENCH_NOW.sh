#!/usr/bin/env bash
set -euo pipefail
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "${LITELLM_MASTER_KEY:-}" ] && [ -f "$dir/.env" ] && { set +u; set -a; . "$dir/.env"; set +a; set -u; }
[ -z "${LITELLM_MASTER_KEY:-}" ] && { echo "ERROR: LITELLM_MASTER_KEY required"; exit 1; }
HDR=(-H "Authorization: Bearer ${LITELLM_MASTER_KEY}")
LOGDIR="/data/stack/_logs"; mkdir -p "$LOGDIR"
CSV="$LOGDIR/bench.csv"; [ -f "$CSV" ] || echo "ts,endpoint,model,ctx,latency_ms,http,tokens_out,tokens_per_s" > "$CSV"

EP_LOCAL="http://localhost:4000";   MD_LOCAL=("fast" "light" "heavy")
EP_FB="http://localhost:4001";      MD_FB=("code.router" "docs.router" "search.router")
SZ=(1000 2000 4000)

now(){ date -Iseconds; }
bench_ep(){ ep="$1"; shift; arr=("$@"); for m in "${arr[@]}"; do for sz in "${SZ[@]}"; do
  p="$(printf 'X%.0s' $(seq 1 $sz))"; t0=$(date +%s%3N)
  r=$(curl -sS --connect-timeout 2 --max-time 25 "${HDR[@]}" -H 'Content-Type: application/json' \
     -w '\n%{http_code}' "$ep/v1/chat/completions" \
     -d "$(jq -n --arg model "$m" --arg p "$p" '{model:$model,messages:[{role:"user",content:$p}],temperature:0}')" ) || r=$'\n0'
  t1=$(date +%s%3N); body="${r%$'\n'*}"; http="${r##*$'\n'}"; ms=$((t1-t0))
  [ "$http" != "200" ] && { echo "SKIP non-200 ep=$ep m=$m sz=$sz http=$http" >&2; continue; }
  out=$(printf '%s' "$body" | jq -r '.choices[0].message.content' 2>/dev/null | tr -d '\r\n' | wc -c | awk '{print $1}')
  tps=0; [ "$ms" -gt 0 ] && tps=$(( out*1000 / ms ))
  echo "$(now),$ep,$m,$sz,$ms,$http,$out,$tps" | tee -a "$CSV" >/dev/null
done; done; }

bench_ep "$EP_LOCAL" "${MD_LOCAL[@]}"
bench_ep "$EP_FB"    "${MD_FB[@]}"
echo "$CSV"
