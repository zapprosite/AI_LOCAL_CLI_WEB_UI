#!/usr/bin/env bash
set -euo pipefail
ROOT=/data/stack
DOCS="$ROOT/docs"
AIGW="$ROOT/ai_gateway"
TS=$(date +%Y%m%dT%H%M%S)
ARC="$ROOT/_archive/$TS"
mkdir -p "$ARC/docs_removed" "$ARC/yml_backups"

# Audit line vivo
AUD_LINE="(audit fail)"
if [ -x "$AIGW/FINAL_AUDIT.sh" ]; then
  AUD_LINE="$("$AIGW/FINAL_AUDIT.sh" | tail -n1 || echo "(audit fail)")"
fi
HOST=$(hostname)
DATE_ISO=$(date -Is)

# Set canônico de docs
CANON=("ARCHIVE_POLICY.md" "BRANCH_POLICY.md" "INDEX.md" "LOGGING_POLICY.md" "NEW_CHAT_PROMPT.md" "NVME_MAP.md" "PRD_FINAL.md" "PR_ollama_integration.md" "README.md")

echo ">>> MOVENDO .md NÃO-CANÔNICOS para $ARC/docs_removed"
shopt -s nullglob
for f in "$DOCS"/*.md; do
  b=$(basename "$f"); keep=0
  for c in "${CANON[@]}"; do [ "$b" = "$c" ] && keep=1 && break; done
  if [ "$keep" -eq 0 ]; then
    echo "REMOVING_MD $b"
    mv "$f" "$ARC/docs_removed/" || true
  fi
done
shopt -u nullglob

# Patching de cabeçalho: Host / Last Audited / Stack Summary code-block
echo ">>> ATUALIZANDO cabeçalhos dos docs canônicos com Audit/Host/Data"
TMP="$(mktemp)"
for f in "$DOCS"/*.md; do
  [ -f "$f" ] || continue
  awk -v host="$HOST" -v iso="$DATE_ISO" -v aud="$AUD_LINE" '
    BEGIN { in_sum=0; replaced=0 }
    # Atualiza Host/Date
    /^> \*\*Host\*\*: /         { print "> **Host**: " host; next }
    /^> \*\*Last Audited\*\*: / { print "> **Last Audited**: " iso; next }

    # Marker do Stack Summary
    /^> \*\*Stack Summary\*\*:/ { print; in_sum=1; next }

    # Na primeira linha do bloco ``` após o marker, injeta nossa versão e pula o bloco antigo
    (in_sum==1 && /^> ```/) {
      print "> ```"
      print "> " aud
      print "> ```"
      in_sum=2; next
    }

    # Se ainda está entre marker e a primeira linha ``` (ruído antigo), pule
    (in_sum==1) { next }

    # Se já imprimimos nosso bloco e vier outro ``` antigo, pule e resete
    (in_sum==2 && /^> ```/) { in_sum=0; next }

    { print }
  ' "$f" > "$TMP" && mv "$TMP" "$f"
  echo "PATCHED $(basename "$f")"
done

# Stash de backups/tmps YML que sujam PR
echo ">>> MOVENDO backups/tmps de YAML do ai_gateway para $ARC/yml_backups"
find "$AIGW" -maxdepth 1 -type f \( -name "*.yml.save" -o -name "*.yml.bak*" -o -name "*.bak.*" -o -name "*.tmp" \) -print -exec mv {} "$ARC/yml_backups/" \; || true

echo ">>> SNAPSHOT FINAL DE DOCS"
ls -1 "$DOCS" | sort
echo "REMOVIDOS:"
ls -1 "$ARC/docs_removed" 2>/dev/null || true
echo "YML_BACKUPS_MOVED:"
ls -1 "$ARC/yml_backups" 2>/dev/null || true

echo "ARCHIVE_AT=$ARC"
