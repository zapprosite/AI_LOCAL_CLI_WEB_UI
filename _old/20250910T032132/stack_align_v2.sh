#!/usr/bin/env bash
# Realinha a árvore conforme PRD. Modos: plan|apply (default: plan).
set -euo pipefail
ROOT="/data/stack"
TS="$(date +%Y%m%dT%H%M%S)"
MODE="${1:-plan}"
PLAN_DIR="$ROOT/_realign"; mkdir -p "$PLAN_DIR"
PLAN="$PLAN_DIR/plan_$TS.txt"

# Canon raiz
keep_root=(
  "ai_gateway" "docs" "_logs" ".github"
  ".gitignore" "AGENTS.md" ".gitattributes"
  ".keep_data_dirs.txt" ".keep_llm_dirs.txt"
)
# Itens tolerados mas marcados (não mover automaticamente)
tolerate_root=( "pulumi_ai_gateway" )

# Map de destino p/ itens não canônicos
dest_old="$ROOT/_old/$TS"; mkdir -p "$dest_old"

is_in() { local x="$1"; shift; for i in "$@"; do [ "$x" = "$i" ] && return 0; done; return 1; }

echo "# REALIGN PLAN $TS ($MODE)"        | tee "$PLAN"
echo "# root=$ROOT dest_old=$dest_old"   | tee -a "$PLAN"

# 1) Raiz
while IFS= read -r entry; do
  base="$(basename "$entry")"
  # ignora git interno e o próprio _old/_realign
  case "$base" in
    ".git"|"_old"|"_realign") continue;;
  esac
  if is_in "$base" "${keep_root[@]}"; then
    echo "KEEP ./$(basename "$entry")" | tee -a "$PLAN"
  elif is_in "$base" "${tolerate_root[@]}"; then
    echo "TOLERATE ./$(basename "$entry")" | tee -a "$PLAN"
  else
    echo "MOVE ./$(basename "$entry") -> $dest_old/" | tee -a "$PLAN"
    [ "$MODE" = "apply" ] && mv -n "$ROOT/$base" "$dest_old/" || true
  fi
done < <(find "$ROOT" -maxdepth 1 -mindepth 1 -printf '%p\n' | LC_ALL=C sort)

# 2) ai_gateway: consolidar estrutura interna mínima
mkdir -p "$ROOT/ai_gateway/config"
# consolidar litellm config (apenas se não existir no caminho canônico)
if [ ! -f "$ROOT/ai_gateway/config/litellm-config.yaml" ] && [ -f "$ROOT/ai_gateway/litellm_config.yaml" ]; then
  echo "FIX ai_gateway: move litellm_config.yaml -> config/litellm-config.yaml" | tee -a "$PLAN"
  [ "$MODE" = "apply" ] && mv "$ROOT/ai_gateway/litellm_config.yaml" "$ROOT/ai_gateway/config/litellm-config.yaml" || true
elif [ -f "$ROOT/ai_gateway/config/litellm-config.yaml" ] && [ -f "$ROOT/ai_gateway/litellm_config.yaml" ]; then
  echo "DUP ai_gateway: manter config/litellm-config.yaml; arquivar litellm_config.yaml em $dest_old" | tee -a "$PLAN"
  [ "$MODE" = "apply" ] && mv -n "$ROOT/ai_gateway/litellm_config.yaml" "$dest_old/" || true
fi

# 3) Garantir scripts-chave presentes (não cria conteúdo)
need_scripts=(UP.sh STATUS.sh CHECK_PORTS.sh WAIT_HEALTH.sh SMOKE_NOW.sh CHAT_MATRIX.sh GEN_PINS.sh UFW_STACK_LAN_ONLY.sh)
for s in "${need_scripts[@]}"; do
  if [ -f "$ROOT/ai_gateway/$s" ]; then
    echo "OK ai_gateway/$s" | tee -a "$PLAN"
  else
    echo "MISS ai_gateway/$s (criar depois se necessário)" | tee -a "$PLAN"
  fi
done

# 4) Saídas finais
echo "TREE_AFTER:" | tee -a "$PLAN"
( cd "$ROOT" && tree -a -L 2 2>/dev/null || ls -la ) | tee -a "$PLAN"

echo "PLAN_FILE=$PLAN"
[ "$MODE" = "plan" ] && echo "Run: sudo /data/stack/stack_align_v2.sh apply"
