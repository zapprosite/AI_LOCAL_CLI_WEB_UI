# PURPOSE: detectar mismatch do LITELLM_MASTER_KEY host vs container.

## 1 THINK
401 em :4000 sugere chave do cliente ≠ chave do container.

## 2 PLAN
Ler .env(s), medir comprimentos, extrair do container e comparar.

## 3 INPUTS
- /data/stack/ai_gateway/.env
- /data/stack/secrets/.env.openai (opcional)

## 4 LOAD_ENV
set -a; [ -f ../secrets/.env.openai ] && . ../secrets/.env.openai; [ -f .env ] && . ./.env; set +a

## 5 COMPOSE_CTX
CF=(-f docker-compose.stack.yml -f docker-compose.pins.yml -f docker-compose.health.yml -f docker-compose.openai.key.yml)

## 6 CID
CID_L="$(docker compose "${CF[@]}" ps -q litellm)"; echo "CID_L=${CID_L:-<none>}"

## 7 CONTAINER_ENV
[ -n "${CID_L:-}" ] && docker inspect "$CID_L" --format '{{range .Config.Env}}{{println .}}{{end}}' \
  | grep -E '^(LITELLM_MASTER_KEY|OPENAI_API_KEY)=' | sed -E 's/(=).*/=<redacted>/'

## 8 LENGTHS
printf 'LEN_HOST_LMK=%s\n' "$(printf %s "${LITELLM_MASTER_KEY-}" | wc -c)"; \
printf 'LEN_CONT_LMK=%s\n' "$( [ -n "${CID_L:-}" ] && docker exec "$CID_L" printenv LITELLM_MASTER_KEY | wc -c || echo 0 )"

## 9 DIFF
[ -n "${CID_L:-}" ] && docker exec "$CID_L" printenv LITELLM_MASTER_KEY | sha256sum | cut -d' ' -f1 | sed 's/^/SHA_CONT_LMK=/' ; \
printf %s "${LITELLM_MASTER_KEY-}" | sha256sum | cut -d' ' -f1 | sed 's/^/SHA_HOST_LMK=/'

## 10 VERIFY
# Se SHA_* diferirem => corrija o .env ou recrie o serviço com a chave correta.
