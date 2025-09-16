# scripts/DATA_STANDARDIZE.sh
#!/usr/bin/env bash
set -euo pipefail

MODE="${MODE:-dry}"   # dry|apply
LOG_PREFIX="[DATA_STD]"
say(){ echo "${LOG_PREFIX} $*"; }

# Pastas alvo (host) e respectivos usos em Compose
HOST_DIRS=(
  "/data/ollama"     # -> /root/.ollama
  "/data/openwebui"  # -> /app/backend/data
  "/data/qdrant"     # -> /qdrant/storage
  "/data/stack/_logs"
  "/data/stack/_archive"
)

ensure_dir() {
  local d="$1"
  if [[ ! -d "$d" ]]; then
    if [[ "$MODE" == "apply" ]]; then
      install -d -m 0775 "$d"
      say "created: $d"
    else
      say "[DRY] would create: $d"
    fi
  else
    say "exists: $d"
  fi
}

fix_perms() {
  local d="$1"
  if [[ "$MODE" == "apply" ]]; then
    chmod -R u+rwX,go+rX "$d" || true
    say "perms fixed: $d"
  else
    say "[DRY] would chmod -R u+rwX,go+rX $d"
  fi
}

# Sugestões de migração (não move sem apply)
MIGRATE_CANDIDATES=(
  "/data/stack/data/ollama -> /data/ollama"
  "/data/stack/data/openwebui -> /data/openwebui"
  "/data/stack/data/qdrant -> /data/qdrant"
)

maybe_migrate() {
  local src="$1" dst="$2"
  if [[ -d "$src" ]]; then
    if [[ "$MODE" == "apply" ]]; then
      rsync -a "$src"/ "$dst"/
      say "migrated: $src -> $dst"
    else
      say "[DRY] would rsync: $src -> $dst"
    fi
  fi
}

main() {
  say "MODE=$MODE"
  for d in "${HOST_DIRS[@]}"; do
    ensure_dir "$d"
    fix_perms "$d"
  done

  # Migrações sugeridas
  maybe_migrate "/data/stack/data/ollama" "/data/ollama"
  maybe_migrate "/data/stack/data/openwebui" "/data/openwebui"
  maybe_migrate "/data/stack/data/qdrant" "/data/qdrant"

  say "SUMMARY:"
  printf "%s\n" "${HOST_DIRS[@]}" | sed 's/^/> /'
}

main "$@"

