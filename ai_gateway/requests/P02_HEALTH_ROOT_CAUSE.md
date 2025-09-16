# PURPOSE: provar que o healthcheck falha por ausência de Authorization.

## 1 THINK
Health atual faz GET /v1/models sem header. Serviço exige Bearer.

## 2 PLAN
Inspecionar .State.Health.Log e test manual com/sem Authorization.

## 3 CID
CF=(-f docker-compose.stack.yml -f docker-compose.pins.yml -f docker-compose.health.yml -f docker-compose.openai.key.yml)
CID_L="$(docker compose "${CF[@]}" ps -q litellm)"; echo "CID_L=${CID_L:-<none>}"

## 4 HEALTH_LOG
[ -n "${CID_L:-}" ] && docker inspect "$CID_L" --format '{{json .State.Health}}' \
  | jq -r '.Log[] | [.ExitCode,(.Output|split("\n")[0])] | @tsv' | tail -n 10

## 5 NO_AUTH_PROBE
exec 3<>/dev/tcp/127.0.0.1/4000; printf "GET /v1/models HTTP/1.1\r\nHost: localhost\r\n\r\n" >&3; head -n1 <&3

## 6 WITH_AUTH_PROBE
curl -sS -o /dev/null -w 'HTTP:%{http_code}\n' -H "Authorization: Bearer ${LITELLM_MASTER_KEY-}" http://127.0.0.1:4000/v1/models

## 7 CLASSIFY
# Se 5) retorna 401/HTTP/1.1 401 e 6) ≠ 200 → chave errada; se 6)=200 → health precisa header.

## 8 RISKS
"unhealthy" ruim para CI e readiness.

## 9 EVIDENCE
# Registre linhas exatas exibidas.

## 10 VERIFY
# Decidir: ajustar chave ou criar overlay de health com header.
