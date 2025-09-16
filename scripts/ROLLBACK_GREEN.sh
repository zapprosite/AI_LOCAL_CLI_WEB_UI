#!/usr/bin/env bash
set -euo pipefail

# Automate rollback to the last green anchor commit.
# Anchor is identified by commit message:
#   feat: V1 stable (compose+pins+health+smoke)

ANCHOR_MSG=${ANCHOR_MSG:-"feat: V1 stable (compose+pins+health+smoke)"}
UTC_TS=$(date -u +%Y%m%dT%H%M%SZ)

have() { command -v "$1" >/dev/null 2>&1; }
err() { echo "ERROR: $*" >&2; exit 1; }
log() { printf '[%s] %s\n' "$UTC_TS" "$*"; }

# Ensure we are in a git repo
have git || err "git not found in PATH"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || err "not inside a git repository"

# Resolve green anchor commit
GOOD=$(git log --grep -F "$ANCHOR_MSG" -n1 --format=%H 2>/dev/null || true)
[ -n "${GOOD:-}" ] || err "could not find green anchor by message: $ANCHOR_MSG"

CURR_BRANCH=$(git rev-parse --abbrev-ref HEAD)
CURR_HASH=$(git rev-parse --short=12 HEAD)
RESCUE_BRANCH="rescue/${UTC_TS}"
RESTORE_BRANCH="chore/runtime-restore"

log "Anchor found: $GOOD"
log "Current: $CURR_BRANCH@$CURR_HASH"

# Create rescue branch from current HEAD (for investigation)
git checkout -B "$RESCUE_BRANCH" HEAD
log "Created rescue branch: $RESCUE_BRANCH"

# Create restore branch from green anchor
git checkout -B "$RESTORE_BRANCH" "$GOOD"
log "Created/updated restore branch: $RESTORE_BRANCH (from anchor)"

cat <<'EOS'

Next steps
----------
1) Push branches:
   git push -u origin $RESCUE_BRANCH
   git push -u origin $RESTORE_BRANCH

2) Open a PR from '$RESTORE_BRANCH' to 'main' with title:
   chore: runtime restore to green anchor

3) Locally verify the green runtime before/after PR:
   docker network create ai_stack_net || true
   cp ai_gateway/.env.example ai_gateway/.env
   docker compose \
     -f ai_gateway/docker-compose.stack.yml \
     -f ai_gateway/docker-compose.pins.yml \
     -f ai_gateway/docker-compose.health.yml \
     up -d
   ai_gateway/WAIT_HEALTH.sh
   ai_gateway/SMOKE_NOW.sh

Notes
-----
- ANCHOR_MSG can be overridden to target a different green anchor.
- This script does not push; manual review is recommended before opening PR.
EOS

