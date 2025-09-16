# PURPOSE: subir litellm_fb e provar :4001 responde.

## 1 THINK
Logs mostraram :4001 down.

## 2 CF_FB
CFB=(-f docker-compose.stack.yml -f docker-compose.pins.yml -f docker-compose.health.yml -f docker-compose.litellm.fb.yml)

## 3 CONFIG
docker compose "${CFB[@]}" config >/dev/null && echo CFG_FB=OK

## 4 UP
docker compose "${CFB[@]}" up -d litellm_fb

## 5 PS
docker compose "${CFB[@]}" ps

## 6 AUTH
AUTH="$(grep -m1 '^LITELLM_MASTER_KEY=' .env | cut -d= -f2-)"

## 7 MODELS
curl -sS -H "Authorization: Bearer $AUTH" http://127.0.0.1:4001/v1/models | jq -r '.data[].id' | sort

## 8 EXPECT
# Deve incluir: code.router docs.router search.router code.hybrid docs.hybrid search.hybrid gpt5

## 9 SANITY CHAT
curl -sS -w '\nHTTP:%{http_code}\n' -H "Authorization: Bearer $AUTH" -H 'Content-Type: application/json' \
  -d '{"model":"code.hybrid","messages":[{"role":"user","content":"2+2? answer with a single digit"}],"temperature":0}' \
  http://127.0.0.1:4001/v1/chat/completions | sed -n '1,12p'

## 10 VERIFY
# HTTP:200 e model inicia com ollama/qwen2.5-coder
