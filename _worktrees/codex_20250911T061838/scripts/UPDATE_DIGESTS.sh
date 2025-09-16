#!/usr/bin/env bash
set -euo pipefail

# Update image digests in ai_gateway/docker-compose.pins.yml
# Strategy:
# - Read service -> current pinned repo@sha256 from pins file
# - Read service -> desired repo:tag from stack file
# - docker pull repo:tag, get digest from RepoDigests
# - If digest changed, replace line in pins file (idempotent)

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STACK_FILE="${STACK_FILE:-$ROOT_DIR/ai_gateway/docker-compose.stack.yml}"
PINS_FILE="${PINS_FILE:-$ROOT_DIR/ai_gateway/docker-compose.pins.yml}"

log(){ printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*"; }
err(){ echo "ERROR: $*" >&2; exit 1; }

[ -f "$STACK_FILE" ] || err "Stack file not found: $STACK_FILE"
[ -f "$PINS_FILE" ] || err "Pins file not found: $PINS_FILE"

# Extract service -> pinned repo and digest from pins file
read_pins(){
  awk '
    BEGIN{svc=""; ins=0}
    /^services:/ {ins=1; next}
    ins && match($0, /^[[:space:]][[:space:]]([A-Za-z0-9_.-]+):[[:space:]]*$/, m) {svc=m[1]; next}
    ins && svc && match($0, /^    image:/) {
      # Extract value manually to avoid awk regex portability issues
      line=$0; sub(/^    image:[[:space:]]*/, "", line); gsub(/"/, "", line);
      img=line; split(img, a, "@"); repo=a[1]; digest=a[2];
      printf "%s %s %s\n", svc, repo, digest;
      svc="";
    }
  ' "$PINS_FILE"
}

# Extract service -> repo:tag from stack file
get_stack_image(){
  local svc="$1"
  awk -v SVC="$svc" '
    BEGIN{svc=""; ins=0}
    /^services:/ {ins=1; next}
    ins && match($0, /^[[:space:]][[:space:]]([A-Za-z0-9_.-]+):[[:space:]]*$/, m) {svc=m[1]; next}
    ins && svc==SVC && match($0, /^    image:/) {
      line=$0; sub(/^    image:[[:space:]]*/, "", line); gsub(/"/, "", line); print line; exit 0
    }
  ' "$STACK_FILE"
}

# Pull tag and read digest (sha256:...)
resolve_digest(){
  local image_tag="$1"
  docker pull "$image_tag" >/dev/null
  # Extract first RepoDigest and cut after '@'
  local rd
  rd=$(docker image inspect --format '{{index .RepoDigests 0}}' "$image_tag" 2>/dev/null || true)
  [ -n "$rd" ] || err "No RepoDigests for $image_tag"
  echo "${rd##*@}"
}

declare -A NEW_IMAGE
changed=0

while read -r svc repo cur_digest; do
  [ -n "$svc" ] || continue
  img_tag="$(get_stack_image "$svc")"
  if [ -z "$img_tag" ]; then
    log "Skip $svc: no image in stack file"
    NEW_IMAGE["$svc"]="$repo@$cur_digest"; continue
  fi
  # Derive repo and tag from stack image
  base_repo="${img_tag%%:*}"
  base_tag="${img_tag#*:}"
  if [ "$base_repo" = "$img_tag" ]; then base_tag="latest"; fi
  desired="$base_repo:$base_tag"
  log "Check $svc → $desired"
  new_digest="$(resolve_digest "$desired")"
  if [ "$new_digest" = "$cur_digest" ]; then
    log "Up-to-date $svc ($cur_digest)"
    NEW_IMAGE["$svc"]="$repo@$cur_digest"; continue
  fi
  new_image="$repo@$new_digest"
  log "Update $svc: $repo@$cur_digest → $new_image"
  NEW_IMAGE["$svc"]="$new_image"
  changed=1
done < <(read_pins)

if [ "$changed" -eq 1 ]; then
  tmp_file="$(mktemp)"
  # Re-write pins file with updated image lines
  cur=""
  while IFS= read -r line; do
    if [[ "$line" =~ ^\ \ ([A-Za-z0-9_.-]+):[[:space:]]*$ ]]; then
      cur="${BASH_REMATCH[1]}"
      echo "$line" >> "$tmp_file"
      continue
    fi
    if [ -n "$cur" ] && [[ "$line" =~ ^\ \ \ \ image: ]]; then
      echo "    image: \"${NEW_IMAGE[$cur]}\"" >> "$tmp_file"
      cur=""
      continue
    fi
    echo "$line" >> "$tmp_file"
  done < "$PINS_FILE"
  mv -f "$tmp_file" "$PINS_FILE"
  log "Pins file updated: $PINS_FILE"
else
  log "No changes detected"
fi
