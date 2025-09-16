#!/usr/bin/env bash
set -euo pipefail

ROOT="/data/stack"
DOCS="$ROOT/docs"
AIGW="$ROOT/ai_gateway"
SCRIPTS="$ROOT/scripts"
TS=$(date +%Y%m%dT%H%M%S)
ARC="$ROOT/_archive/$TS"
TRASH="$ROOT/_trash/$TS"
LOGS="$ROOT/_logs"

mkdir -p "$ARC" "$TRASH" "$LOGS"

echo "=== SNAPSHOT BEFORE ==="
hostname; date -Is; id
echo "--- tree /data/stack (L2) ---"
tree -a -L 2 -I '.git|_archive|_trash|_logs|node_modules|__pycache__|.venv|venv' "$ROOT" || true
echo "--- du /data/stack ---"
du -h -d1 "$ROOT" | sort -h | tail -n 20

# 0) Coletar contexto vivo da stack
AUD_LINE="(no audit)"
if [ -x "$AIGW/FINAL_AUDIT.sh" ]; then
  AUD_LINE="$("$AIGW/FINAL_AUDIT.sh" | tail -n1 || echo "(audit fail)")"
fi
HOST=$(hostname)
DATE_ISO=$(date -Is)

# 1) .gitignore endurecido (backup + replace)
if [ -f "$ROOT/.gitignore" ]; then cp -a "$ROOT/.gitignore" "$ARC/.gitignore.bak"; fi
cat > "$ROOT/.gitignore" <<'GIT'
# === Core ===
/.git/
/.gitmodules
/.gitattributes
/.yamllint.yml

# === Large/Generated ===
/_archive/
/_trash/
/_logs/
/backups/
/pr_artifacts/
/_worktrees/
/_old/
/_realign/
/observability/
/pr_artifacts/*
/data/*
/*.tgz
*.tgz
*.tar
*.zip

# === App Data (not source) ===
/ai_gateway/logs/
/ai_gateway/requests/
/ai_gateway/tests/tmp/
/ai_gateway/*.db
/openwebui/
/qdrant/
/ollama/
/llm/

# === Secrets ===
/secrets/*
!.keep_*

# === Node / Python / misc ===
node_modules/
__pycache__/
*.pyc
*.pyo
*.pyd
*.log
*.log.*
*.sqlite
*.sqlite3
*.db
.DS_Store

# === Build caches ===
dist/
build/
.cache/
GIT
echo "GITIGNORE=OK"

# 2) Normalizador de docs (gera _refactored e só depois substitui)
REF="$DOCS/_refactored"
mkdir -p "$REF"
TEMPLATE="$DOCS/.template.md"

cat > "$TEMPLATE" <<'TMD'
# {{TITLE}}

> **Status**: synchronized  
> **Host**: {{HOST}}  
> **Last Audited**: {{DATE}}  
> **Stack Summary**:  
> ```
> {{AUDIT_LINE}}
> ```

## Overview
Short purpose of this document in the AI local stack (GPU + LiteLLM Router + Ollama + OpenWebUI + Qdrant). Keep it concise and actionable.

## Architecture Context
- Router (ports 4000/4001), hybrids: code/docs/search → fallback openai/gpt-5  
- Local models via Ollama (qwen2.5-coder:14b etc.)
- OpenWebUI as OpenAI-compatible client  
- Vector store: Qdrant

## Operations (Terminal-only)
- Health: `ai_gateway/WAIT_HEALTH.sh`  
- Smoke: `ai_gateway/SMOKE_NOW.sh`  
- Final audit: `ai_gateway/FINAL_AUDIT.sh`

## How to Use
Step-by-step relevant to this document. Example requests, env vars, compose overlays.

## Troubleshooting
Common pitfalls + quick commands.

## Legacy Notes
(Original content preserved below)
TMD

norm_one() {
  in="$1"
  base=$(basename "$in")
  title="${base%.*}"
  out="$REF/$base"

  sed "s/{{TITLE}}/$title/g; s/{{HOST}}/$HOST/g; s/{{DATE}}/$DATE_ISO/g; s|{{AUDIT_LINE}}|$AUD_LINE|g" "$TEMPLATE" > "$out"
  echo "" >> "$out"
  echo "----" >> "$out"
  echo "## Legacy Notes (raw)" >> "$out"
  echo "" >> "$out"
  cat "$in" >> "$out" || true
  echo "DOC_REFACTORED: $base"
}

echo "=== DOCS REFACTOR ==="
shopt -s nullglob
for f in "$DOCS"/*.md; do
  [ "$(basename "$f")" = "_refactored" ] && continue
  [ -d "$f" ] && continue
  norm_one "$f"
done
shopt -u nullglob

# swap seguro: move originais para _archive e coloca _refactored no lugar
mkdir -p "$ARC/docs_backup"
cp -a "$DOCS"/*.md "$ARC/docs_backup/" || true
cp -a "$REF"/*.md "$DOCS"/
rm -rf "$REF" "$TEMPLATE"
echo "DOCS_OK -> backup em $ARC/docs_backup"

# 3) Aparar scripts inúteis (sem deletar, move p/ _archive)
echo "=== SCRIPTS TRIM ==="
KEEP_LIST="$AIGW/KEEP_AIGW.list"
# fallback: se não existir, cria whitelist mínima
if [ ! -f "$KEEP_LIST" ]; then
  cat > "$KEEP_LIST" <<'K'
WAIT_HEALTH.sh
SMOKE_NOW.sh
FINAL_AUDIT.sh
HEALTH_DASH.sh
FB_RECOVER.sh
SMOKE_FB.sh
SMOKE_ROUTER.sh
BENCH_NOW.sh
REPORT_HYBRID_FROM_LOGS.sh
VERIFY_HYBRID_FROM_LOGS.sh
MODEL_PULL.sh
K
fi

mkdir -p "$ARC/sh_removed" "$ARC/sh_dupes"
declare -A seen

scan_trim() {
  base_dir="$1"
  [ -d "$base_dir" ] || return 0
  while IFS= read -r -d '' f; do
    b="$(basename "$f")"
    # heurísticas de remoção segura
    size=$(stat -c%s "$f" || echo 0)
    execbit=0; [ -x "$f" ] && execbit=1
    keep=0
    # keep se na whitelist
    grep -qx "$b" "$KEEP_LIST" && keep=1
    # keep se usado nos últimos 30 dias
    recent=$(find "$f" -mtime -30 -print -quit | wc -l || echo 0)
    [ "$recent" -gt 0 ] && keep=1
    # dupes por md5
    md5=$(md5sum "$f" 2>/dev/null | awk '{print $1}')
    if [ -n "${seen[$md5]-}" ]; then
      echo "DUPLICATE $f == ${seen[$md5]}"
      mv "$f" "$ARC/sh_dupes/$(basename "$f").$TS" || true
      continue
    else
      seen[$md5]="$f"
    fi
    # critérios de “inútil”: não-exec + muito pequeno + não keep
    if [ "$keep" -eq 0 ] && [ "$execbit" -eq 0 ] && [ "$size" -lt 160 ]; then
      echo "TRIM $f (size=$size, exec=$execbit)"
      mkdir -p "$ARC/sh_removed$(dirname "$f" | sed "s|$ROOT||")"
      mv "$f" "$ARC/sh_removed/" || true
    fi
  done < <(find "$base_dir" -maxdepth 1 -type f -name '*.sh' -print0 2>/dev/null)
}

scan_trim "$AIGW"
scan_trim "$SCRIPTS"
echo "SCRIPTS_OK -> ver $ARC/sh_removed e $ARC/sh_dupes"

# 4) Logs antigos: compressão e arquivamento
echo "=== LOGS TRIM ==="
mkdir -p "$ARC/logs_moved"
# compacta logs > 20MB
find "$ROOT" -type f -name '*.log' -size +20M -exec gzip -9 {} \; 2>/dev/null || true
# move logs com mtime > 14 dias
find "$ROOT" -type f -name '*.log*' -mtime +14 -not -path "$ARC/*" -print -exec mv {} "$ARC/logs_moved/" \; || true
echo "LOGS_OK"

# 5) Gerar novo INDEX.md com TOC
echo "=== DOCS INDEX ==="
IDX="$DOCS/INDEX.md"
if [ -f "$IDX" ]; then cp -a "$IDX" "$ARC/INDEX.md.bak"; fi
{
  echo "# Documentation Index"
  echo ""
  for f in $(ls "$DOCS"/*.md | sort); do
    bn=$(basename "$f")
    t="${bn%.*}"
    echo "- [$t](./$bn)"
  done
} > "$IDX"
echo "INDEX_OK"

# 6) Snapshot AFTER
echo "=== SNAPSHOT AFTER ==="
tree -a -L 2 -I '.git|_archive|_trash|_logs|node_modules|__pycache__|.venv|venv' "$ROOT" || true
du -h -d1 "$ROOT" | sort -h | tail -n 20
echo "ARCHIVE AT: $ARC"

exit 0
