# PURPOSE: checar OPENAI_API_KEY direto na API sem abortar fluxo.

## 1 THINK
401 no HEAD indica credencial inválida/escopo.

## 2 PLAN
curl -sSI e -sS head -c 200.

## 3 EXEC-HEAD
curl -sSI https://api.openai.com/v1/models -H "Authorization: Bearer ${OPENAI_API_KEY-}" | head -n1 || true

## 4 EXEC-BODY
curl -sS  https://api.openai.com/v1/models -H "Authorization: Bearer ${OPENAI_API_KEY-}" | head -c 200 || true; echo

## 5 CLASSIFY
# 200 ok | 401 unauth

## 6 DECIDE
# Se 401 → não testar fallbacks reais até corrigir a key.

## 7 CONTAINER_CHECK
CID_L="$(docker compose -f docker-compose.stack.yml -f docker-compose.pins.yml -f docker-compose.health.yml -f docker-compose.openai.key.yml ps -q litellm)" ; \
[ -n "${CID_L:-}" ] && docker inspect "$CID_L" --format '{{range .Config.Env}}{{println .}}{{end}}' | grep '^OPENAI_API_KEY=' | sed -E 's/(=).*/=<redacted>/'

## 8 LENGTHS
printf 'LEN_OPENAI_HOST=%s\n' "$(printf %s "${OPENAI_API_KEY-}" | wc -c)"

## 9 RISK
# Key inválida impede fallback.

## 10 VERIFY
# Registrar status.
