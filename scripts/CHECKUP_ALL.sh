#!/usr/bin/env bash
set -euo pipefail

# Orchestrates health (WAIT/SMOKE/AUDIT), data standardize (dry/apply),
# model listings, Qdrant seeds, and aggregates everything into logcodex.

BASE_DIR="/data/stack"
GW_DIR="$BASE_DIR/ai_gateway"
SCRIPTS_DIR="$BASE_DIR/scripts"
LOGS_DIR="$BASE_DIR/_logs"
PRD_FILE="$BASE_DIR/docs/specs/PRD_MAP_TEST_DEBUG.md"
TS_UTC="$(date -u +%Y%m%dT%H%M%SZ)"

echo "[CHECKUP] ts=$TS_UTC"
mkdir -p "$LOGS_DIR"

# Archive old logs first
if [ -x "$SCRIPTS_DIR/logs_archive.sh" ]; then
  "$SCRIPTS_DIR/logs_archive.sh" || true
fi

# Ensure env keys exist
cd "$GW_DIR"
if ! grep -q '^LITELLM_MASTER_KEY=' .env 2>/dev/null; then
  echo "LITELLM_MASTER_KEY=$(openssl rand -hex 16)" | tee -a .env
fi
if ! grep -q '^POSTGRES_PASSWORD=' .env 2>/dev/null; then
  echo "POSTGRES_PASSWORD=$(openssl rand -hex 16)" | tee -a .env
fi

# Compose config (include FB overlay for :4001) — stack expected to be running already
if docker compose \
  -f docker-compose.stack.yml \
  -f docker-compose.pins.yml \
  -f docker-compose.health.yml \
  -f docker-compose.litellm.fb.yml \
  -f docker-compose.openwebui.provider.yml config >/dev/null; then
  echo "[CHECKUP] compose config OK"
else
  echo "[CHECKUP] compose config FAILED" >&2
fi

# Health + Smoke + Audit
./WAIT_HEALTH.sh | tee "$LOGS_DIR/wait.txt"
./SMOKE_NOW.sh   | tee "$LOGS_DIR/smoke.txt"
./FINAL_AUDIT.sh | tee "$LOGS_DIR/audit.txt"

# Data standardize (dry/apply)
cd "$BASE_DIR"
MODE=dry   "$SCRIPTS_DIR/DATA_STANDARDIZE.sh" | tee "$LOGS_DIR/data_std_dry.txt"
MODE=apply "$SCRIPTS_DIR/DATA_STANDARDIZE.sh" | tee "$LOGS_DIR/data_std_apply.txt"

# Model listings
cd "$GW_DIR"
: > "$LOGS_DIR/models_4000.txt" || true
curl -s http://127.0.0.1:4000/v1/models | jq -r '.data[]?.id' | head -n 40 | tee "$LOGS_DIR/models_4000.txt" || true
KEY=$(awk -F= '/^LITELLM_MASTER_KEY=/{print $2}' .env)
curl -s -H "Authorization: Bearer $KEY" http://127.0.0.1:4001/v1/models \
  | jq -r '.data[]?.id' | head -n 40 | tee "$LOGS_DIR/models_4001.txt" || true

# Qdrant seeds
python3 "$SCRIPTS_DIR/qdrant_seed_agents.py" | tee "$LOGS_DIR/qdrant_seed.txt" || true

# Aggregate into timestamped file and Desktop
OUT_ARCHIVE="$LOGS_DIR/logcodex_${TS_UTC}.md"
{
  echo "# logcodex.md"
  echo
  echo "## Source: $PRD_FILE"; echo; cat "$PRD_FILE"; echo; echo "---"; echo
  echo "## Source: $SCRIPTS_DIR/qdrant_seed_agents.py"; echo; cat "$SCRIPTS_DIR/qdrant_seed_agents.py"; echo; echo "---"; echo
  echo "## Source: $LOGS_DIR/wait.txt"; echo; cat "$LOGS_DIR/wait.txt"; echo; echo "---"; echo
  echo "## Source: $LOGS_DIR/smoke.txt"; echo; cat "$LOGS_DIR/smoke.txt"; echo; echo "---"; echo
  echo "## Source: $LOGS_DIR/audit.txt"; echo; cat "$LOGS_DIR/audit.txt"; echo; echo "---"; echo
  echo "## Source: $LOGS_DIR/models_4000.txt"; echo; cat "$LOGS_DIR/models_4000.txt" 2>/dev/null || true; echo; echo "---"; echo
  echo "## Source: $LOGS_DIR/models_4001.txt"; echo; cat "$LOGS_DIR/models_4001.txt" 2>/dev/null || true; echo; echo "---"; echo
  echo "## Source: $LOGS_DIR/qdrant_seed.txt"; echo; cat "$LOGS_DIR/qdrant_seed.txt" 2>/dev/null || true; echo; echo "---"; echo
  echo "## Source: $LOGS_DIR/ollama_tail.txt"; echo; cat "$LOGS_DIR/ollama_tail.txt" 2>/dev/null || true; echo; echo "---"; echo
  echo "## Source: $LOGS_DIR/nvidia_smi.txt"; echo; cat "$LOGS_DIR/nvidia_smi.txt" 2>/dev/null || true; echo
} > "$OUT_ARCHIVE"

echo "[CHECKUP] aggregated: $OUT_ARCHIVE"

# Copy to Desktop as logcodex.md
if command -v xdg-user-dir >/dev/null 2>&1; then
  DESK_DIR="$(xdg-user-dir DESKTOP)"
else
  DESK_DIR="$HOME/Desktop"
fi
mkdir -p "$DESK_DIR"
cp -f "$OUT_ARCHIVE" "$DESK_DIR/logcodex.md"
echo "[CHECKUP] desktop copy: $DESK_DIR/logcodex.md"

# Optionally copy to repo root as convenience
cp -f "$OUT_ARCHIVE" "$BASE_DIR/logcodex.md" || true

echo "[CHECKUP] done"