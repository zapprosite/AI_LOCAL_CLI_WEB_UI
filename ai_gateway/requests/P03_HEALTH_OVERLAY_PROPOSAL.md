# PURPOSE: propor overlay que adiciona Authorization no healthcheck.

## 1 THINK
Base intocada; overlay adicional.

## 2 PLAN
Arquivo: docker-compose.health.auth.yml, apenas service litellm.healthcheck.

## 3 YAML
cat <<'YAML'
services:
  litellm:
    healthcheck:
      test: ["CMD-SHELL","curl -fsS -H 'Authorization: Bearer ${LITELLM_MASTER_KEY}' http://localhost:4000/v1/models >/dev/null"]
      interval: 10s
      timeout: 5s
      retries: 6
      start_period: 5s
YAML

## 4 NOTE
# Variável expandida pelo Compose, não no container.

## 5 ALT
# Se curl indisponível na imagem, substituir por bash TCP com header completo.

## 6 NO-APPLY
# Só revisão.

## 7 RISK
# Interpolação de var exige env no compose.

## 8 VERIFY
# Aguardar aprovação.

## 9 NEXT
# P04 escreve e valida.

## 10 END
