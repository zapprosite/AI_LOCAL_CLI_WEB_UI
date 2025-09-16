#!/usr/bin/env bash
set -euo pipefail

hdr(){ printf '\n===== %s =====\n' "$*"; }

BASE="/data/stack"
GATE="$BASE/ai_gateway"
LOG="$BASE/_logs/TREE_NOW.txt"
mkdir -p "$BASE/_logs"

hdr "HOST/USER/TIME"
hostname; date -Is; id

hdr "TREE /data/stack (nível 2, exclusões comuns)"
tree -a -L 2 -I '.git|_archive|_logs|node_modules|__pycache__|.venv|venv' "$BASE" || true

hdr "TREE /data/stack/ai_gateway (nível 2)"
tree -a -L 2 -I '.git|_archive|_logs' "$GATE" || true

hdr "COMPOSE FILES DETECTADOS"
find "$GATE" -maxdepth 1 -type f -name 'docker-compose*.yml' -print | sort || true

hdr "DOTENVs E SECRETS (comprimentos e 1ª linha)"
if [ -f "$GATE/.env" ]; then
  echo "[.env]"; sed -n '1,20p' "$GATE/.env"
  LEN_LMK=$(grep -m1 '^LITELLM_MASTER_KEY=' "$GATE/.env" | cut -d= -f2- | wc -c | tr -d ' ')
else echo "MISSING: $GATE/.env"; LEN_LMK=0; fi
if [ -f "$BASE/secrets/.env.openai" ]; then
  echo "[secrets/.env.openai]"; sed -n '1,3p' "$BASE/secrets/.env.openai"
  LEN_OPENAI=$(grep -m1 '^OPENAI_API_KEY=' "$BASE/secrets/.env.openai" | cut -d= -f2- | wc -c | tr -d ' ')
else echo "MISSING: $BASE/secrets/.env.openai"; LEN_OPENAI=0; fi
printf 'LEN_LMK=%s LEN_OPENAI=%s\n' "$LEN_LMK" "$LEN_OPENAI"

hdr "OVERLAYS CHAVE (head)"
for f in \
  "$GATE/litellm.router.fb.yml" \
  "$GATE/docker-compose.litellm.fb.yml" \
  "$GATE/docker-compose.openwebui.provider.yml" \
  "$GATE/docker-compose.health.auth.yml" \
  "$GATE/docker-compose.health.yml" \
  "$GATE/docker-compose.stack.yml" \
  "$GATE/docker-compose.pins.yml"
do
  [ -f "$f" ] && { echo "--- $f"; sed -n '1,80p' "$f"; } || echo "MISSING: $f"
done

hdr "GREPs ÚTEIS (onde define base/key do OpenWebUI e Router)"
grep -RIn --binary-files=without-match -E 'OPENAI_API_BASE_URL|OPENAI_API_KEY|LITELLM_MASTER_KEY|model_list|code\.hybrid|code\.router' "$GATE" || true

hdr "DOCKER NETWORK ai_stack_net"
docker network inspect ai_stack_net --format '{{.Name}} {{.Driver}} containers={{len .Containers}}' || true
docker ps --format '{{.Names}}\t{{.Status}}\t{{.Ports}}' | sort

hdr "COMPOSE CONFIG CHECK (auto-monta lista existente)"
cd "$GATE"
CF=( docker-compose.stack.yml docker-compose.pins.yml docker-compose.health.yml )
[ -f docker-compose.litellm.fb.yml ] && CF+=( docker-compose.litellm.fb.yml )
[ -f docker-compose.openwebui.provider.yml ] && CF+=( docker-compose.openwebui.provider.yml )
echo "USING:" "${CF[@]}"
docker compose -f "${CF[0]}" -f "${CF[1]}" -f "${CF[2]}" ${CF[@]:3:+-f "${CF[@]:3}"} config >/dev/null \
  && echo "COMPOSE_CONFIG=OK" || echo "COMPOSE_CONFIG=FAIL"

hdr "PROBES /v1/models (:4000 e :4001) com Authorization se disponível"
AUTH="$(grep -m1 '^LITELLM_MASTER_KEY=' .env 2>/dev/null | cut -d= -f2- || true)"
printf 'AUTH_LEN=%s\n' "$(printf %s "$AUTH" | wc -c | tr -d ' ')"
if [ -n "${AUTH:-}" ]; then
  echo "--- :4000"
  curl -sS -H "Authorization: Bearer $AUTH" http://127.0.0.1:4000/v1/models | jq -r '.data[].id' | sort || true
  echo "--- :4001"
  curl -sS -H "Authorization: Bearer $AUTH" http://127.0.0.1:4001/v1/models | jq -r '.data[].id' | sort || true
else
  echo "Sem AUTH; pulei curls."
fi
