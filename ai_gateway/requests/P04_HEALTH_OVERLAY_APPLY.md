# PURPOSE: escrever overlay e validar sem side-effects globais.

## 1 THINK
Somar overlay de health ao conjunto CF.

## 2 WRITE
sudo tee <<'YML' /data/stack/ai_gateway/docker-compose.health.auth.yml
services:
  litellm:
    healthcheck:
      test: ["CMD-SHELL","curl -fsS -H 'Authorization: Bearer ${LITELLM_MASTER_KEY}' http://localhost:4000/v1/models >/dev/null"]
      interval: 10s
      timeout: 5s
      retries: 6
      start_period: 5s
YML

## 3 CONFIG
CF=(-f docker-compose.stack.yml -f docker-compose.pins.yml -f docker-compose.health.yml -f docker-compose.health.auth.yml -f docker-compose.openai.key.yml)

## 4 CHECK
docker compose "${CF[@]}" config >/dev/null && echo CFG_HEALTH=OK

## 5 REDEPLOY
docker compose "${CF[@]}" up -d litellm

## 6 AWAIT
sleep 6

## 7 STATUS
docker compose "${CF[@]}" ps

## 8 HEALTH_JSON
CID_L="$(docker compose "${CF[@]}" ps -q litellm)"; docker inspect "$CID_L" --format '{{json .State.Health.Status}}'

## 9 VERIFY
# Esperado: healthy.

## 10 NOTE
# Se continuar 401, volte ao P01 para chave errada no container.
