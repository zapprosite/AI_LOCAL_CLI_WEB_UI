#!/usr/bin/env bash
set -euo pipefail
ROOT=/data/stack
DOCS="$ROOT/docs"
CANON=("ARCHIVE_POLICY.md" "BRANCH_POLICY.md" "INDEX.md" "LOGGING_POLICY.md" "NEW_CHAT_PROMPT.md" "NVME_MAP.md" "PRD_FINAL.md" "PR_ollama_integration.md" "README.md")

# 1) Somente docs canônicos
status=0
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

# 2) Stack Summary vivo obrigatório
AUD_RE='^> SUMMARY :4000=[0-9]{3} :4001=[0-9]{3} .* qdrant=[0-9]{3}$'
for c in "${CANON[@]}"; do
  f="$DOCS/$c"
  [ -f "$f" ] || { echo "DOCPOLICY_FAIL: ausente $c"; status=1; continue; }
  # precisa ter cabeçalho Stack Summary e um bloco com a linha SUMMARY final do audit
  if ! grep -q '^> \*\*Stack Summary\*\*:' "$f"; then
    echo "DOCPOLICY_FAIL: sem header 'Stack Summary' em $c"; status=1
  fi
  # extrai bloco e testa linha
  if ! awk '
    BEGIN{in=0}
    /^> \*\*Stack Summary\*\*:/ {in=1; next}
    (in==1 && /^> ```/) {in=2; next}
    (in==2 && /^> ```/) {in=0; next}
    (in==2) {gsub("^> ",""); print}
  ' "$f" | grep -Pq '"$AUD_RE"'; then
    echo "DOCPOLICY_FAIL: Stack Summary sem linha SUMMARY viva em $c"
    status=1
  fi
done

[ $status -eq 0 ] && echo "DOCPOLICY_OK" || exit $status
