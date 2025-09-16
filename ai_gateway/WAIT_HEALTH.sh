#!/usr/bin/env bash
set -euo pipefail
AUTH=$(grep -m1 '^LITELLM_MASTER_KEY=' /data/stack/ai_gateway/.env | cut -d= -f2-)
chk(){ curl -sS -o /dev/null -w '%{http_code}' -H "Authorization: Bearer ${AUTH}" "http://127.0.0.1:$1/v1/models" || echo 000; }
for port in 4000 4001; do
  for i in {1..30}; do code=$(chk $port); echo "PORT=$port TRY=$i HTTP=$code"; [ "$code" = "200" ] && break; sleep 2; done
done
