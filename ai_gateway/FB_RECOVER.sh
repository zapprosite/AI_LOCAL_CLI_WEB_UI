#!/usr/bin/env bash
set -euo pipefail
CF="-f docker-compose.stack.yml -f docker-compose.pins.yml -f docker-compose.health.yml -f docker-compose.litellm.fb.yml -f docker-compose.litellm.fb.logs.yml"
echo ">>> restart FB"; docker compose $CF restart litellm_fb || true
CID=$(docker compose $CF ps -q litellm_fb || true); echo CID=$CID
for i in {1..20}; do s=$(docker inspect "$CID" --format '{{.State.Health.Status}}' 2>/dev/null || true); echo "health=$s try=$i"; [ "$s" = "healthy" ] && exit 0; sleep 2; done
echo ">>> forced recreate"; docker compose $CF up -d --force-recreate litellm_fb
CID=$(docker compose $CF ps -q litellm_fb || true); echo CID=$CID
for i in {1..25}; do s=$(docker inspect "$CID" --format '{{.State.Health.Status}}' 2>/dev/null || true); echo "health=$s try=$i"; [ "$s" = "healthy" ] && exit 0; sleep 2; done
echo "RECOVER_FAIL"
