#!/usr/bin/env bash
set -eu
NET=ai_stack_net
docker network inspect "$NET" >/dev/null 2>&1 || docker network create "$NET"

have() { command -v "$1" >/dev/null 2>&1; }
cid(){ docker inspect -f '{{.Id}}' "$1" 2>/dev/null || true; }

connected() {
  local n="$1" c="$2" id; id="$(cid "$c")"
  [ -n "$id" ] || return 1
  docker network inspect "$n" | jq -e --arg id "$id" '.[]?.Containers? | has($id)' >/dev/null 2>&1
}

alias_present() {
  local n="$1" c="$2" a="$3" id; id="$(cid "$c")"
  [ -n "$id" ] || return 1
  docker network inspect "$n" \
    | jq -e --arg id "$id" --arg a "$a" '.[]?.Containers?[$id]?.Aliases? // [] | index($a) != null' >/dev/null 2>&1
}

ensure_with_alias() {
  local c="$1" a="$2"
  docker ps --format '{{.Names}}' | grep -qx "$c" || return 0
  if connected "$NET" "$c"; then
    if alias_present "$NET" "$c" "$a"; then
      echo "OK $c já conectado com alias $a"
    else
      echo "Reanexando $c com alias $a"
      docker network disconnect "$NET" "$c" || true
      docker network connect --alias "$a" "$NET" "$c"
    fi
  else
    echo "Conectando $c com alias $a"
    docker network connect --alias "$a" "$NET" "$c"
  fi
}

ensure_plain() {
  local c="$1"
  docker ps --format '{{.Names}}' | grep -qx "$c" || return 0
  if connected "$NET" "$c"; then
    echo "OK $c já conectado"
  else
    echo "Conectando $c"
    docker network connect "$NET" "$c"
  fi
}

ensure_with_alias ai_gateway-ollama-1 ollama
ensure_with_alias ai_gateway-qdrant-1 qdrant
ensure_plain litellm

echo "DONE $NET"
