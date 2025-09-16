#!/usr/bin/env bash
set -euo pipefail
ROOT=/data/stack
DOCS="$ROOT/docs"
CANON=("ARCHIVE_POLICY.md" "BRANCH_POLICY.md" "INDEX.md" "LOGGING_POLICY.md" "NEW_CHAT_PROMPT.md" "NVME_MAP.md" "PRD_FINAL.md" "PR_ollama_integration.md" "README.md")

status=0

# 1) Apenas docs canônicos
shopt -s nullglob
for f in "$DOCS"/*.md; do
  base=$(basename "$f")
  keep=0; for c in "${CANON[@]}"; do [ "$base" = "$c" ] && keep=1 && break; done
  if [ "$keep" -eq 0 ]; then
    echo "DOCPOLICY_FAIL: arquivo não-canônico: $base"
    status=1
  fi
done
shopt -u nullglob

# 2) Stack Summary vivo (tolerante)
AUD_RE='^SUMMARY :4000=[0-9]{3} :4001=[0-9]{3} .* qdrant=[0-9]{3}$'

for c in "${CANON[@]}"; do
  f="$DOCS/$c"
  [ -f "$f" ] || { echo "DOCPOLICY_FAIL: ausente $c"; status=1; continue; }

  # header obrigatório
  if ! grep -q '^> \*\*Stack Summary\*\*:' "$f"; then
    echo "DOCPOLICY_FAIL: sem header 'Stack Summary' em $c"
    status=1
  fi

  # 2.1) Caminho feliz: linha de summary direta (prefixo '> ')
  SUM="$(grep -E -m1 '^> SUMMARY :4000=[0-9]{3} :4001=[0-9]{3} .* qdrant=[0-9]{3}$' "$f" | sed 's/^> //')"

  # 2.2) Fallback: extrair bloco fenced após o header com awk POSIX e [*]
  if [ -z "${SUM}" ]; then
    SUM="$(
      awk '
        BEGIN{in_hdr=0; in_blk=0}
        /^> [*][*]Stack Summary[*][*]:/ {in_hdr=1; next}
        (in_hdr==1 && /^> ```/) {in_blk=1; in_hdr=0; next}
        (in_blk==1 && /^> ```/) {in_blk=0; next}
        (in_blk==1) { sub(/^> /,""); print }
      ' "$f" | grep -E -m1 '"$AUD_RE"'
    )"
  fi

  if ! printf '%s\n' "$SUM" | grep -Eq "$AUD_RE"; then
    echo "DOCPOLICY_FAIL: Stack Summary sem linha SUMMARY viva em $c"
    status=1
  fi
done

[ $status -eq 0 ] && echo "DOCPOLICY_OK" || exit $status
