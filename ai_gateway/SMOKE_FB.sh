#!/usr/bin/env bash
set -euo pipefail
set -o pipefail

# SMOKE_FB: Validate fallback router on :4001
# Steps:
# 1) Assert /v1/models lists code/docs/search aliases
# 2) Chat on code.router (HTTP 200, small answer)
# 3) Chat with metadata.high_stakes=true; print backend model
# 4) Simulate local failure (api_base -> http://ollama:65535), reload litellm_fb; assert fallback used (openai)
# 5) Restore original router

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$dir/.." && pwd)"
compose_fb="$dir/docker-compose.litellm.fb.yml"
log_dir="$root/_logs"
log_file="$log_dir/smoke_fb.txt"

mkdir -p "$log_dir"

# Load secrets from .env (for LITELLM_MASTER_KEY); do not echo values
if [[ -z "${LITELLM_MASTER_KEY:-}" ]] && [[ -f "$dir/.env" ]]; then
  set +u; set -a; . "$dir/.env"; set +a; set -u
fi

if [[ -z "${LITELLM_MASTER_KEY:-}" ]]; then
  echo "ERROR: LITELLM_MASTER_KEY required (ai_gateway/.env)" >&2
  exit 1
fi

HDR=(-H "Authorization: Bearer ${LITELLM_MASTER_KEY}")

sanitize() {
  sed -E \
    -e "s/(Authorization:[[:space:]]*Bearer)[^'\"]*/\1 ***REDACTED***/Ig" \
    -e "s/([Bb]earer)[[:space:]]+[A-Za-z0-9._-]+/\1 ***REDACTED***/g" \
    -e "s/(LITELLM_MASTER_KEY=)[^[:space:]]+/\1***REDACTED***/g" \
    -e "s/(OPENAI_API_KEY=)[^[:space:]]+/\1***REDACTED***/g"
}

fail=0
tmp_created=""
orig_backup=""

restore_router() {
  # Restore original router if we replaced it
  if [[ -n "$orig_backup" && -f "$orig_backup" ]]; then
    local target
    target="${orig_backup%.bak}"
    mv -f "$orig_backup" "$target" || true
  fi
}
trap restore_router EXIT

run() { "$@"; }

wait_ready() {
  local url="$1" tries="${2:-20}" delay="${3:-2}" i http
  for ((i=1;i<=tries;i++)); do
    http="$(curl -sS "${HDR[@]}" -o /dev/null -w '%{http_code}' "$url" || echo 000)"
    [[ "$http" == "200" ]] && return 0
    sleep "$delay"
  done
  return 1
}

ensure_overlay() {
  if [[ ! -f "$compose_fb" ]]; then
    if [[ -x "$root/scripts/fb_overlay_up.sh" ]]; then
      "$root/scripts/fb_overlay_up.sh" >/dev/null || true
    fi
  fi
  if [[ ! -f "$compose_fb" ]]; then
    echo "ERROR: missing overlay compose $compose_fb" >&2
    exit 1
  fi
}

switch_full_router() {
  if [[ -x "$root/scripts/fb_router_switch.sh" ]]; then
    "$root/scripts/fb_router_switch.sh" full >/dev/null || true
  fi
}

compose_up() {
  docker compose -f "$compose_fb" up -d litellm_fb
}

get_mapped_router_path() {
  local p
  p="$(grep -E "^[[:space:]]*-\s+/data/stack/ai_gateway/litellm\\.router(\\.local)?\\.yml:/app/litellm\\.router\\.yml:ro" -m1 "$compose_fb" \
      | sed -E 's/^.*-\s+([^:]+):.*/\1/' || true)"
  if [[ -z "$p" ]]; then p="/data/stack/ai_gateway/litellm.router.yml"; fi
  printf '%s' "$p"
}

tmpfile() { mktemp -t smoke_fb.XXXXXX; }

req_models() {
  local ep="$1" tmp http
  tmp="$(tmpfile)"
  http="$(curl -sS "${HDR[@]}" "$ep/v1/models" -o "$tmp" -w '%{http_code}' || echo 000)"
  echo "GET $ep/v1/models -> HTTP ${http}"
  if [[ "$http" == "200" ]]; then
    jq -r '.data[].id' < "$tmp" 2>/dev/null | sort || true
  else
    head -c 256 "$tmp" 2>/dev/null; echo
  fi
  rm -f "$tmp"
  [[ "$http" == "200" ]]
}

chat() {
  local ep="$1" model="$2" prompt="$3" extra_json="$4" tmp http content used_model
  tmp="$(tmpfile)"
  local data
  if [[ -n "$extra_json" ]]; then
    data=$(jq -c --arg m "$model" --arg p "$prompt" --argjson extra "$extra_json" '{model:$m,metadata:$extra,messages:[{role:"user",content:$p}],temperature:0}')
  else
    data=$(jq -c --arg m "$model" --arg p "$prompt" '{model:$m,messages:[{role:"user",content:$p}],temperature:0}')
  fi
  http="$(curl -sS "${HDR[@]}" -H 'Content-Type: application/json' "$ep/v1/chat/completions" -d "$data" -o "$tmp" -w '%{http_code}' || echo 000)"
  content="$(jq -r '.choices[0].message.content // ""' < "$tmp" 2>/dev/null | tr -d '\r')"
  used_model="$(jq -r '.model // ""' < "$tmp" 2>/dev/null | tr -d '\r')"
  echo "$http"; printf '%s\n' "$used_model"; printf '%s' "$content"
  rm -f "$tmp"
}

{
  echo "== SMOKE_FB =="
  echo "Auth: LITELLM_MASTER_KEY=***REDACTED***"

  ensure_overlay
  initial_map="$(get_mapped_router_path)"
  switch_full_router
  echo "Bringing up litellm_fb (compose overlay)"
  compose_up || true
  echo "Waiting for /v1/models on :4001"
  if wait_ready "http://localhost:4001/v1/models" 20 2; then
    echo "Service ready"
  else
    echo "WARN: service not ready yet; continuing"
  fi

  echo "[1] List models on :4001 and assert aliases present"
  if req_models "http://localhost:4001"; then
    if curl -sS "${HDR[@]}" http://localhost:4001/v1/models | jq -r '.data[].id' | grep -qx 'code.router' \
      && curl -sS "${HDR[@]}" http://localhost:4001/v1/models | jq -r '.data[].id' | grep -qx 'docs.router' \
      && curl -sS "${HDR[@]}" http://localhost:4001/v1/models | jq -r '.data[].id' | grep -qx 'search.router'; then
      echo "PASS models: found code.router, docs.router, search.router"
    else
      echo "FAIL models: missing required aliases"
      fail=$((fail+1))
    fi
  else
    echo "FAIL /v1/models HTTP != 200"
    fail=$((fail+1))
  fi

  echo "[2] Chat on code.router (expect HTTP 200 and small answer)"
  mapfile -t c1 < <(chat "http://localhost:4001" "code.router" "Say 'hi' in one word." "")
  http_c1="${c1[0]:-000}"; used_c1="${c1[1]:-}"; content_c1="$(printf '%s\n' "${c1[@]:2}")"
  echo "HTTP ${http_c1}"
  echo "Model (reported): ${used_c1}"
  echo "Content: $(printf '%s' "$content_c1" | tr '\n' ' ' | sed 's/  */ /g' | head -c 160)"
  if [[ "$http_c1" != "200" ]]; then
    echo "FAIL chat step 2: HTTP ${http_c1}"; fail=$((fail+1))
  else
    # small answer heuristic
    if [[ $(printf '%s' "$content_c1" | wc -c) -gt 300 ]]; then
      echo "WARN: answer seems long ($(printf '%s' "$content_c1" | wc -c) chars)"
    else
      echo "PASS chat step 2"
    fi
  fi

  echo "[3] Chat with metadata.high_stakes=true (print backend model)"
  extra='{ "high_stakes": true }'
  mapfile -t c2 < <(chat "http://localhost:4001" "code.router" "2+2?" "$extra")
  http_c2="${c2[0]:-000}"; used_c2="${c2[1]:-}"; content_c2="$(printf '%s\n' "${c2[@]:2}")"
  echo "HTTP ${http_c2}"
  echo "Backend used (model): ${used_c2}"
  echo "Content: $(printf '%s' "$content_c2" | tr '\n' ' ' | sed 's/  */ /g' | head -c 160)"
  if [[ "$http_c2" != "200" ]]; then
    echo "FAIL chat step 3: HTTP ${http_c2}"; fail=$((fail+1))
  fi

  echo "[4] Simulate local failure for code.router (api_base -> http://ollama:65535) and assert fallback"
  mapped_cfg="$(get_mapped_router_path)"
  echo "Mapped router file: ${mapped_cfg}"
  if [[ ! -f "$mapped_cfg" ]]; then
    echo "FAIL: mapped router file not found"; fail=$((fail+1))
  else
    orig_backup="${mapped_cfg}.bak"
    cp -f "$mapped_cfg" "$orig_backup"
    tmp_mod="$(tmpfile)"; tmp_created="$tmp_mod"
    awk '
      BEGIN{in_code=0}
      /^\s*-\s*model_name:\s*code\.router\s*$/ {in_code=1; print; next}
      in_code && /^\s*-\s*model_name:/ {in_code=0; print; next}
      in_code && /^\s*api_base\s*:/ {sub(/api_base:.*/,"api_base: http://ollama:65535"); print; next}
      {print}
    ' "$mapped_cfg" > "$tmp_mod"
    mv -f "$tmp_mod" "$mapped_cfg"
    echo "Reloading litellm_fb"
    compose_up || true
    if wait_ready "http://localhost:4001/v1/models" 20 2; then echo "Reloaded"; else echo "WARN: not ready yet"; fi

    # Now call with high_stakes, expect fallback to openai
    mapfile -t c3 < <(chat "http://localhost:4001" "code.router" "quick check" "$extra")
    http_c3="${c3[0]:-000}"; used_c3="${c3[1]:-}"; content_c3="$(printf '%s\n' "${c3[@]:2}")"
    echo "HTTP ${http_c3}"
    echo "Backend used (model): ${used_c3}"
    echo "Content: $(printf '%s' "$content_c3" | tr '\n' ' ' | sed 's/  */ /g' | head -c 160)"
    if [[ "$http_c3" == "200" && "$used_c3" == openai/* || "$used_c3" == openai* || "$used_c3" == *"openai"* ]]; then
      echo "PASS fallback engaged (model=${used_c3})"
    else
      echo "FAIL: expected fallback to openai (HTTP=${http_c3}, model=${used_c3})"; fail=$((fail+1))
    fi
  fi

  echo "[5] Restore original router and reload"
  restore_router || true
  # Restore prior mapping if it was local-only
  if [[ -n "$initial_map" && "$initial_map" == *"litellm.router.local.yml"* ]] && [[ -x "$root/scripts/fb_router_switch.sh" ]]; then
    "$root/scripts/fb_router_switch.sh" local >/dev/null || true
  fi
  compose_up || true
  wait_ready "http://localhost:4001/v1/models" 20 2 || true

  if [[ "$fail" -eq 0 ]]; then
    echo "== RESULT: PASS =="
  else
    echo "== RESULT: FAIL (${fail}) =="
    exit 1
  fi
} | sanitize | tee "$log_file"

echo "Saved log -> $log_file"
