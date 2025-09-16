# PR: Integração Ollama + Routers LiteLLM

## Objetivo
Garantir que o LiteLLM consuma modelos locais via Ollama com persistência em /data.

## Mudanças
- docker-compose.ollama.vol.yml: monta /data/ollama -> /root/.ollama e alias 'ollama' na ai_stack_net.
- config/litellm-config.yaml: routers 'task:code-router' e 'task:docs-router' apontando http://ollama:11434.
- Scripts existentes de health/smoke continuam válidos.

## Riscos e Rollback
Baixo. Remover overlay e recriar serviço `ai_gateway-ollama-1`.

## Validação
1. `docker compose -f docker-compose.yml -f docker-compose.ollama.vol.yml up -d ai_gateway-ollama-1`
2. `docker exec -i litellm sh -lc "python3 - <<'PY'\nimport urllib.request;print(urllib.request.urlopen('http://ollama:11434/api/tags',timeout=3).read(200))\nPY"`
3. `curl -s 127.0.0.1:4000/v1/models`
4. `echo '2+2?' | codex --code -`  # deve responder

## Checklist
- [ ] `/api/tags` lista modelos
- [ ] `/v1/models` OK
- [ ] `codex --code -` responde
