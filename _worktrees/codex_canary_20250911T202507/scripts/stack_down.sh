#!/usr/bin/env bash
set -euo pipefail
docker compose -f /data/stack/compose.yaml down -v
