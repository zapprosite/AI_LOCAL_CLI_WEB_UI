#!/usr/bin/env bash
set -euo pipefail

# Idempotently install cron entry for CHECKUP_ALL.sh (hourly)
CRON_TAG="# AI_LOCAL_CLI_WEB_UI CHECKUP_ALL"
CRON_LINE="0 * * * * /bin/bash /data/stack/scripts/CHECKUP_ALL.sh >> /data/stack/_logs/checkup_cron.log 2>&1 $CRON_TAG"

TMP_CRON=$(mktemp)
# Preserve existing crontab if any
crontab -l 2>/dev/null > "$TMP_CRON" || true

# Remove existing tagged lines
grep -v "$CRON_TAG" "$TMP_CRON" > "${TMP_CRON}.clean" || true

# Append our line
printf "%s\n" "$CRON_LINE" >> "${TMP_CRON}.clean"

# Install new crontab
crontab "${TMP_CRON}.clean"

rm -f "$TMP_CRON" "${TMP_CRON}.clean"

echo "Cron installed: $CRON_LINE"