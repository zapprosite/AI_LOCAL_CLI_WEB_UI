# PURPOSE: confirmar modelos e arquivos de config usados por cada porta.

## 1 THINK
:4000 usa config local; :4001 deve usar fb.yml.

## 2 LIST_FILES
ls -1 litellm.router*.yml | sort

## 3 GREP_GPT5
grep -nE 'model_name: *gpt5|openai/gpt-5' litellm.router*.yml || true

## 4 WHICH_CONFIG_4000
docker compose -f docker-compose.stack.yml -f docker-compose.pins.yml -f docker-compose.health.yml -f docker-compose.openai.key.yml ps -q litellm | \
xargs -r docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' | grep '^LITELLM_CONFIG=' || echo 'LITELLM_CONFIG_4000=unset'

## 5 WHICH_CONFIG_4001
docker compose -f docker-compose.stack.yml -f docker-compose.pins.yml -f docker-compose.health.yml -f docker-compose.litellm.fb.yml ps -q litellm_fb | \
xargs -r docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' | grep '^LITELLM_CONFIG=' || echo 'LITELLM_CONFIG_4001=unset'

## 6 EXPECT
# 4001 → LITELLM_CONFIG=/app/litellm.router.fb.yml

## 7 RISK
# Config errado impede *.hybrid.

## 8 VERIFY
# Anotar saídas.

## 9 NEXT
# Ajuste via compose se necessário (overlay).

## 10 END
