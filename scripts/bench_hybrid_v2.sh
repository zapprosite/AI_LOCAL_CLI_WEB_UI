#!/usr/bin/env bash
set -Eeuo pipefail
AUTH="$(grep -m1 '^LITELLM_MASTER_KEY=' /data/stack/ai_gateway/.env | cut -d= -f2-)"
LOG=/data/stack/_logs/bench.csv; TS=$(date -Is)
bench_one(){ mode="$1"; data="$2"; t0=$(date +%s%3N); resp=$(curl -sS -w '\nHTTP:%{http_code}\n' -H "Authorization: Bearer $AUTH" -H 'Content-Type: application/json' -d "$data" http://127.0.0.1:4001/v1/chat/completions || true); t1=$(date +%s%3N); ms=$((t1-t0)); code=$(printf '%s\n' "$resp" | sed -n 's/^HTTP://p' | tail -n1); model=$(printf '%s\n' "$resp" | sed '/^HTTP:/d' | jq -r '.model // .choices[0].model // empty'); tok=$(printf '%s\n' "$resp" | sed '/^HTTP:/d' | jq -r '.usage.completion_tokens // 0'); line="$TS,code.hybrid,$mode,${ms},${tok},HTTP:${code:-000},${model:-}"; [ "${code:-000}" = "200" ] && echo "$line" >> "$LOG"; echo "$line"; }
bench_one local  '{"model":"code.hybrid","messages":[{"role":"user","content":"2+2? single digit"}],"temperature":0,"max_tokens":8}'
bench_one stakes '{"model":"code.hybrid","metadata":{"high_stakes":true},"messages":[{"role":"user","content":"ok"}],"temperature":0,"max_tokens":8}'
