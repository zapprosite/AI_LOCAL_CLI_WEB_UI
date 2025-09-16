# PURPOSE: provar fallback via *.hybrid e retorno ao primário.

## 1 THINK
STOP ollama → high_stakes → openai/*; START → volta a ollama/*.

## 2 AUTH
AUTH="$(grep -m1 '^LITELLM_MASTER_KEY=' .env | cut -d= -f2-)"

## 3 STOP
docker stop ai_gateway-ollama-1 && sleep 3

## 4 FB_CHAT
curl -sS -w '\nHTTP:%{http_code}\n' -H "Authorization: Bearer $AUTH" -H 'Content-Type: application/json' \
  -d '{"model":"code.hybrid","metadata":{"high_stakes":true},"messages":[{"role":"user","content":"reply: OK"}],"temperature":0}' \
  http://127.0.0.1:4001/v1/chat/completions | sed -n '1,12p'

## 5 START
docker start ai_gateway-ollama-1 && sleep 5

## 6 BACK_CHAT
curl -sS -w '\nHTTP:%{http_code}\n' -H "Authorization: Bearer $AUTH" -H 'Content-Type: application/json' \
  -d '{"model":"code.hybrid","messages":[{"role":"user","content":"2+2?"}],"temperature":0}' \
  http://127.0.0.1:4001/v1/chat/completions | sed -n '1,12p'

## 7 EXPECT
# FB_CHAT model ~ ^openai/ ; BACK_CHAT model ~ ^ollama/qwen2.5-coder

## 8 RISK
# Se curl 000 → proxy FB down (voltar ao P05).

## 9 LOGS
# Coletar tail do serviço litellm_fb se necessário.

## 10 VERIFY
# Confirmar troca de provider.
