#!/usr/bin/env bash
set -euo pipefail

# stack_minify_v1.sh
# Moves non-allowlisted files/dirs into _archive/<timestamp>/ (dry-run by default)
# Reads allowlists from:
#  - KEEP_ROOT.list (optional, repo root)
#  - ai_gateway/KEEP_AIGW.list (required for ai_gateway subpaths; falls back to sane defaults)
#  - docs/KEEP_DOCS.list (optional; if missing, keeps entire docs/)
# Usage:
#   MODE=dry   ./stack_minify_v1.sh   # preview only (default)
#   MODE=apply ./stack_minify_v1.sh   # perform moves

MODE=${MODE:-dry}
ROOT_DIR=$(cd "$(dirname "$0")" && pwd)
ARCHIVE_DIR="${ROOT_DIR}/_archive"
TS=$(date -u +%Y%m%dT%H%M%SZ)
TARGET_SNAPSHOT="${ARCHIVE_DIR}/${TS}"

echo "[info] mode=${MODE}"
echo "[info] root=${ROOT_DIR}"

shopt -s dotglob nullglob

# Helpers
is_tracked() {
  git ls-files --error-unmatch -- "$1" >/dev/null 2>&1
}

move_path() {
  local src=$1
  local dst=$2
  if [[ "${MODE}" == "dry" ]]; then
    echo "DRY-MOVE: ${src} -> ${dst}"
    return 0
  fi
  mkdir -p "$(dirname "${dst}")"
  if is_tracked "${src}" && command -v git >/dev/null 2>&1; then
    if git mv -f "${src}" "${dst}"; then
      echo "MOVED: ${src} -> ${dst}"
      return 0
    else
      echo "[warn] git mv failed for ${src}; trying plain mv" >&2
    fi
  fi
  if mv -f "${src}" "${dst}" 2>/dev/null; then
    echo "MOVED: ${src} -> ${dst}"
  else
    echo "[warn] move failed for ${src} (insufficient perms?). Leaving source in place and copying." >&2
    if cp -a "${src}" "${dst}" 2>/dev/null; then
      echo "COPIED: ${src} -> ${dst} (source retained)"
    else
      echo "[error] copy also failed for ${src}. Skipping." >&2
    fi
  fi
}

read_list_file() {
  # Reads non-empty, non-comment lines from a list file if it exists
  local list_file=$1
  if [[ -f "${list_file}" ]]; then
    sed -e 's/#.*$//' -e '/^\s*$/d' "${list_file}"
  fi
}

# Build root allowlist
declare -A KEEP_ROOT
if [[ -f "${ROOT_DIR}/KEEP_ROOT.list" ]]; then
  echo "[info] USING KEEP_ROOT.list"
  while IFS= read -r p; do KEEP_ROOT["$p"]=1; done < <(read_list_file "${ROOT_DIR}/KEEP_ROOT.list")
else
  echo "[info] KEEP_ROOT.list missing; using conservative defaults"
  for p in \
    ai_gateway \
    scripts \
    docs \
    apps \
    modelfiles \
    .github \
    .gitignore \
    .gitattributes \
    .yamllint.yml \
    README.md CHANGELOG.md LICENSE CONTRIBUTING.md AGENTS.md \
    compose.yaml stack_realign.sh stack_minify_v1.sh .keep_data_dirs.txt .keep_llm_dirs.txt
  do KEEP_ROOT["$p"]=1; done
fi

# Always keep these internal infra dirs
for p in .git _archive _logs; do KEEP_ROOT["$p"]=1; done

# ai_gateway sub-allowlist
declare -A KEEP_AIGW
if [[ -f "${ROOT_DIR}/ai_gateway/KEEP_AIGW.list" ]]; then
  while IFS= read -r p; do KEEP_AIGW["$p"]=1; done < <(read_list_file "${ROOT_DIR}/ai_gateway/KEEP_AIGW.list")
else
  # Fallback defaults based on repo guidelines
  for p in \
    docker-compose.stack.yml docker-compose.pins.yml docker-compose.health.yml \
    docker-compose.impact_ui.yml docker-compose.openwebui.pin.yml \
    docker-compose.litellm.entrypoint.yml docker-compose.litellm.healthfix.yml \
    docker-compose.qdrant.healthfix.yml docker-compose.litellm.cmd.yml \
    .env .env.example config WAIT_HEALTH.sh SMOKE_NOW.sh README.md tests .github
  do KEEP_AIGW["$p"]=1; done
fi

# docs sub-allowlist (optional). If missing, keep entire docs/
declare -A KEEP_DOCS
DOCS_LIST="${ROOT_DIR}/docs/KEEP_DOCS.list"
DOCS_MODE="whole"
if [[ -f "${DOCS_LIST}" ]]; then
  DOCS_MODE="partial"
  while IFS= read -r p; do KEEP_DOCS["$p"]=1; done < <(read_list_file "${DOCS_LIST}")
fi

echo "[info] docs mode=${DOCS_MODE}"

# Plan moves at root level
ROOT_MOVES=()
for path in ${ROOT_DIR}/* ${ROOT_DIR}/.*; do
  base=$(basename -- "$path")
  [[ -e "$path" ]] || continue
  # Skip current dir and parent
  [[ "$base" == "." || "$base" == ".." ]] && continue
  # Respect keep root
  if [[ -n "${KEEP_ROOT[$base]:-}" ]]; then
    continue
  fi
  ROOT_MOVES+=("$base")
done

if (( ${#ROOT_MOVES[@]} > 0 )); then
  echo "[plan] root moves: ${#ROOT_MOVES[@]}"
  for b in "${ROOT_MOVES[@]}"; do
    move_path "${ROOT_DIR}/${b}" "${TARGET_SNAPSHOT}/${b}"
  done
else
  echo "[plan] root moves: none"
fi

# ai_gateway scoped moves (only if directory exists)
if [[ -d "${ROOT_DIR}/ai_gateway" ]]; then
  AIGW_MOVES=()
  pushd "${ROOT_DIR}/ai_gateway" >/dev/null
  for path in * .*; do
    base="$path"
    [[ -e "$base" ]] || continue
    [[ "$base" == "." || "$base" == ".." ]] && continue
    if [[ -n "${KEEP_AIGW[$base]:-}" ]]; then
      continue
    fi
    AIGW_MOVES+=("$base")
  done
  popd >/dev/null
  if (( ${#AIGW_MOVES[@]} > 0 )); then
    echo "[plan] ai_gateway moves: ${#AIGW_MOVES[@]}"
    for b in "${AIGW_MOVES[@]}"; do
      move_path "${ROOT_DIR}/ai_gateway/${b}" "${TARGET_SNAPSHOT}/ai_gateway/${b}"
    done
  else
    echo "[plan] ai_gateway moves: none"
  fi
fi

# docs scoped moves
if [[ -d "${ROOT_DIR}/docs" ]]; then
  if [[ "${DOCS_MODE}" == "partial" ]]; then
    DOCS_MOVES=()
    pushd "${ROOT_DIR}/docs" >/dev/null
    for path in * .*; do
      base="$path"
      [[ -e "$base" ]] || continue
      [[ "$base" == "." || "$base" == ".." ]] && continue
      if [[ -n "${KEEP_DOCS[$base]:-}" ]]; then
        continue
      fi
      DOCS_MOVES+=("$base")
    done
    popd >/dev/null
    if (( ${#DOCS_MOVES[@]} > 0 )); then
      echo "[plan] docs moves: ${#DOCS_MOVES[@]}"
      for b in "${DOCS_MOVES[@]}"; do
        move_path "${ROOT_DIR}/docs/${b}" "${TARGET_SNAPSHOT}/docs/${b}"
      done
    else
      echo "[plan] docs moves: none"
    fi
  else
    echo "[plan] docs moves: none (whole docs/ kept)"
  fi
fi

echo "[done] minify ${MODE} complete. Snapshot: ${TARGET_SNAPSHOT}"
