#!/usr/bin/env bash
set -euo pipefail
docker network inspect ai_stack >/dev/null 2>&1 || docker network create ai_stack
docker compose -f /data/stack/compose.yaml up -d
for i in $(seq 1 60); do
  curl -sfm 2 127.0.0.1:4000/v1/models >/dev/null && break
  sleep 0.5
done
curl -s 127.0.0.1:4000/v1/models | jq '.data|length // 0'
