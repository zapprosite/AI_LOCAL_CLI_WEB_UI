#!/usr/bin/env bash
# Realinha a árvore /data/stack conforme PRD_FINAL.md
set -euo pipefail
BASE="/data/stack"
AG="$BASE/ai_gateway"

log() { printf '%s\n' "$*"; }

###############################################################################
# 1. Pastas garantidas
###############################################################################
mkdir -p "$BASE/docs" "$BASE/_labs" "$BASE/_logs"
mkdir -p "$AG/logs" "$AG/_old" "$AG/config"

###############################################################################
# 2. Arquivos Compose e YAML redundantes → _old/
###############################################################################
# padrões a mover (exceto docker-compose.stack.yml e envs)
find "$AG" -maxdepth 1 -type f \( \
     -name 'docker-compose.litellm*.yml' -o \
     -name 'docker-compose.*.yml' ! -name 'docker-compose.stack.yml' -o \
     -name 'litellm*.yaml' ! -path "$AG/config/litellm-config.yaml" \) \
     -print -exec mv -f {} "$AG/_old/" \;

# diretório conf antigo
[ -d "$AG/conf" ] && mv "$AG/conf" "$AG/_old/conf_\$(date +%Y%m%dT%H%M%S)" || true

###############################################################################
# 3. Diretórios laboratoriais → _labs/
###############################################################################
for d in fullstackfx js_v1_sbx langgraph_* upstream stack_v1; do
  [ -d "$BASE/$d" ] && mv "$BASE/$d" "$BASE/_labs/" || true
done

###############################################################################
# 4. Logs fora do lugar → _logs/
###############################################################################
[ -d "$BASE/_out" ] && mv "$BASE/_out" "$BASE/_logs/out_\$(date +%Y%m%dT%H%M%S)" || true

###############################################################################
# 5. Placeholders para scripts essenciais
###############################################################################
create_stub() {
  local file="$1"; shift
  if [ ! -f "$file" ]; then
    cat >"$file" <<'STUB'
#!/usr/bin/env bash
# TODO: implementar
exit 0
STUB
    chmod +x "$file"
    log "Criado placeholder: $file"
  fi
}
create_stub "$AG/CHECK_PORTS.sh"
create_stub "$AG/UP.sh"
create_stub "$AG/STATUS.sh"

###############################################################################
# 6. Permissões de execução (caso já existam)
###############################################################################
chmod +x "$AG/"{CHECK_PORTS.sh,UP.sh,STATUS.sh} 2>/dev/null || true

###############################################################################
# 7. Sumário
###############################################################################
log "================= REALIGN SUMMARY ================"
log "Diretórios garantidos:"
log "  $AG/logs  $AG/_old  $AG/config  $BASE/docs  $BASE/_labs  $BASE/_logs"
log "Arquivos placeholders verificados/criados:"
ls -1 "$AG/"{CHECK_PORTS.sh,UP.sh,STATUS.sh}
log "Arquivos/YAML movidos para _old/:"
ls -1 "$AG/_old" || true
log "Diretórios movidos para _labs/:"
ls -1 "$BASE/_labs" || true
log "=================================================="
