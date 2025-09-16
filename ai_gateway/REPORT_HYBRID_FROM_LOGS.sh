#!/usr/bin/env bash
# Gera relatório a partir de LOGS existentes. Não executa testes.
set -Eeuo pipefail
LOGDIR=${1:-/data/stack/_logs}
ARTDIR=/data/stack/pr_artifacts
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
OUT="$ARTDIR/hybrid_report_$TS.md"
mkdir -p "$ARTDIR"

VERIFY=/data/stack/ai_gateway/VERIFY_HYBRID_FROM_LOGS.sh
if [[ ! -x "$VERIFY" ]]; then
  echo "ERR: verifier não encontrado em $VERIFY" >&2
  exit 2
fi

TMP=$(mktemp)
"$VERIFY" "$LOGDIR" | tee "$TMP" >/dev/null || true
PASS=$(grep -m1 '^PASS=' "$TMP" | cut -d= -f2- || echo false)
MODELS_OK=$(grep -m1 '^MODELS_OK=' "$TMP" | cut -d= -f2- || echo false)
LOCAL_OK=$(grep -m1 '^LOCAL_OK=' "$TMP" | cut -d= -f2- || echo 0)
FB_OK=$(grep -m1 '^FB_OK=' "$TMP" | cut -d= -f2- || echo 0)
BACK_OK=$(grep -m1 '^BACK_OK=' "$TMP" | cut -d= -f2- || echo 0)

headsafe(){
  local f="$1"; local n="$2"
  [[ -s "$f" ]] || return 0
  echo; echo "<details><summary>${f##*/}</summary>"
  sed -n "1,${n}p" "$f" | sed 's/</\&lt;/g'
  echo "</details>"
}

{
  echo "# Hybrid Fallback Report — $TS"
  echo
  echo "- PASS=$PASS"
  echo "- MODELS_OK=$MODELS_OK"
  echo "- LOCAL_OK=$LOCAL_OK"
  echo "- FB_OK=$FB_OK"
  echo "- BACK_OK=$BACK_OK"
  echo
  echo "## Evidências (capas)"
  headsafe "$LOGDIR/models_4001.txt" 80
  headsafe "$LOGDIR/chat_hybrid_local.txt" 40
  headsafe "$LOGDIR/chat_hybrid_fb.txt" 40
  headsafe "$LOGDIR/chat_hybrid_back_local.txt" 40
  headsafe "$LOGDIR/litellm_fb_tail.txt" 80
  headsafe "$LOGDIR/verify_hybrid.out" 80
} >"$OUT"

sha=$(sha256sum "$OUT" | awk '{print $1}')
echo "REPORT=$OUT"
echo "SHA256=$sha"
