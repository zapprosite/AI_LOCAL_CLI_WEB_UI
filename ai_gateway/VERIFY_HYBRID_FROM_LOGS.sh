#!/usr/bin/env bash
set -euo pipefail
LOGDIR="${1:-/data/stack/_logs}"
echo "== VERIFY @ $(date -Is) LOGDIR=$LOGDIR =="

shopt -s nullglob

# 1) Dump de modelos se existir
if [ -f "$LOGDIR/models_4001.txt" ]; then
  echo "-- MODELS (models_4001.txt) --"
  sed -n '1,120p' "$LOGDIR/models_4001.txt"
else
  echo "WARN: models_4001.txt ausente"
fi

# 2) Varrer chats híbridos e extrair HTTP e modelo
ok=0; fail=0; unk=0
for f in "$LOGDIR"/chat_hybrid_*.txt; do
  echo "=== FILE: $(basename "$f") ==="
  HTTP_LINE="$(grep -m1 -E '^HTTP/' "$f" || true)"
  if [ -n "$HTTP_LINE" ]; then
    echo "HTTP=$HTTP_LINE"
    if echo "$HTTP_LINE" | grep -qE ' 200 '; then ok=$((ok+1)); else fail=$((fail+1)); fi
  else
    echo "HTTP=<none>"
    unk=$((unk+1))
  fi

  # Extrair "model" de forma tolerante
  TAIL="$(tail -n 200 "$f")"
  MODEL="$(printf '%s\n' "$TAIL" | awk 'match($0,/"model"[[:space:]]*:[[:space:]]*"[^\"]+"/){m=substr($0,RSTART,RLENGTH); sub(/^"model"[[:space:]]*:[[:space:]]*"/,"",m); sub(/"$/,"",m); print m}' | tail -n1)"
  if [ -z "${MODEL:-}" ]; then
    MODEL="$(printf '%s\n' "$TAIL" | awk 'match($0,/"choices"[[:space:]]*:[[:space:]]*\[[^]]*"model"[[:space:]]*:[[:space:]]*"[^\"]+"/){s=substr($0,RSTART,RLENGTH); sub(/.*"model"[[:space:]]*:[[:space:]]*"/,"",s); sub(/"$/,"",s); print s}' | tail -n1)"
  fi
  echo "MODEL=${MODEL:-<unknown>}"
done

# 3) Resumo
echo "-- SUMMARY --"
echo "OK=$ok FAIL=$fail UNKNOWN=$unk"
