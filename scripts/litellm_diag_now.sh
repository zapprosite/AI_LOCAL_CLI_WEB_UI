#!/usr/bin/env bash
set -Eeuo pipefail

ONLY="/data/stack/ai_gateway/docker-compose.litellm.only.yml"
FIX="/data/stack/ai_gateway/docker-compose.litellm.cmdfix.yml"
CFG="/data/stack/ai_gateway/config/litellm-config.yaml"

echo "== 1/5 Verificando YAML no host =="
[ -s "$CFG" ] || { echo "ERRO: $CFG ausente/vazio"; exit 1; }
head -n 40 "$CFG" || true
echo

echo "== 2/5 Subindo litellm (isolado) com cmd fixado =="
docker compose -f "$ONLY" -f "$FIX" up -d --remove-orphans litellm

CID="$(docker compose -f "$ONLY" ps -q litellm || true)"
[ -n "$CID" ] || { echo "ERRO: litellm não criado"; exit 1; }
echo "Container: $CID"

echo "== 3/5 Aguardando porta :4000 (máx 30s) =="
for i in {1..30}; do
  nc -z 127.0.0.1 4000 2>/dev/null && { echo "OK 4000 aberta"; break; }
  sleep 1
  [ "$i" -eq 30 ] && { echo "FALHA: porta 4000 não abriu"; docker compose -f "$ONLY" logs --since=120s --no-log-prefix litellm || true; exit 1; }
done

echo "== 4/5 Diagnóstico interno =="
echo "-- YAML montado --"
docker exec -i "$CID" sh -lc 'ls -l /config/litellm-config.yaml && echo "---"; sed -n "1,80p" /config/litellm-config.yaml' || true
echo "-- Processos --"
docker exec -i "$CID" sh -lc 'ps aux | head -n 80' || true
echo "-- Sockets --"
docker exec -i "$CID" sh -lc 'ss -lntp 2>/dev/null || netstat -lntp 2>/dev/null || true' | sed -n '1,120p'

echo "== 5/5 Logs recentes (devem mostrar o YAML impresso pelo entrypoint) =="
docker compose -f "$ONLY" logs --since=40s --no-log-prefix litellm || true
