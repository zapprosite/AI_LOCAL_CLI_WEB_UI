#!/usr/bin/env bash
set -euo pipefail
BASE="/data/stack/_logs"
MAX_LINES="${MAX_LINES:-0}" # 0 = imprimir completo
err(){ echo "ERRO: $*" >&2; exit 1; }
[ -d "$BASE" ] || err "Base inexistente: $BASE"

read_one() {
  local p="$1"
  local rp; rp="$(realpath -e "$p" 2>/dev/null || true)"
  [ -n "$rp" ] || { echo "SKIP (não existe): $p"; return 0; }
  [[ "$rp" == "$BASE/"* ]] || err "Fora de $BASE: $rp"
  echo "===== BEGIN $rp ====="
  if [ "$MAX_LINES" -gt 0 ]; then
    tail -n +"1" "$rp" | head -n "$MAX_LINES"
  else
    cat "$rp"
  fi
  echo "===== END $rp ====="
  rm -f -- "$rp"
  echo "REMOVED: $rp"
}
if [ "$#" -eq 0 ]; then
  err "Uso: READ_AND_PURGE.sh <arquivos_em_/data/stack/_logs>"
fi
for f in "$@"; do read_one "$f"; done
