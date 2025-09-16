#!/usr/bin/env bash
set -euo pipefail
ROOT=/data/stack
AIGW="$ROOT/ai_gateway"
AUTH=$(grep -m1 '^LITELLM_MASTER_KEY=' "$AIGW/.env" | cut -d= -f2-)

echo "== WAIT_HEALTH =="
"$AIGW/WAIT_HEALTH.sh"

echo "== SMOKE =="
"$AIGW/SMOKE_NOW.sh"

echo "== FINAL_AUDIT =="
LINE=$("$AIGW/FINAL_AUDIT.sh" | tail -n1)
echo "$LINE"

# Regras mínimas
echo "$LINE" | grep -qE ' :4000=200 ' || { echo "CI_FAIL: :4000 != 200"; exit 1; }
echo "$LINE" | grep -qE ' :4001=200 ' || { echo "CI_FAIL: :4001 != 200"; exit 1; }
echo "$LINE" | grep -q 'MODELS4000=\[fast,light,heavy\]' || { echo "CI_FAIL: aliases fast|light|heavy ausentes"; exit 1; }
echo "$LINE" | grep -q 'code.hybrid.local=200' || { echo "CI_FAIL: hybrid local falhou"; exit 1; }
echo "$LINE" | grep -q 'code.hybrid.fb=200' || { echo "CI_FAIL: hybrid fallback falhou"; exit 1; }

echo "== SECRET SCAN (repo) =="
cd "$ROOT"
# padrões simples; ignora secrets/ e _archive/
rg -n --hidden --ignore-file <(printf "_archive\nsecrets\n") \
  -e 'OPENAI_API_KEY\s*=' \
  -e 'sk-[A-Za-z0-9]{20,}' \
  -e 'AKIA[0-9A-Z]{16}' \
  -e '-----BEGIN (RSA|OPENSSH) PRIVATE KEY-----' \
  || true

echo "CI_LOCAL_OK"
