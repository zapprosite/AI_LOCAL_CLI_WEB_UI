# PR_ollama_integration

> **Status**: synchronized  
> **Host**: zappro
> **Last Audited**: 2025-09-16T06:04:13-03:00
> **Stack Summary**:  
> ```
> SUMMARY :4000=200 :4001=200 MODELS4000=[fast,light,heavy] MODELS4001=[code.hybrid,docs.hybrid,search.hybrid,code.remote,docs.remote,search.remote,code.router,docs.router,search.router,openai.gpt5] fast=200 code.router=200 code.hybrid.local=200 code.hybrid.fb=200 openwebui="ai_gateway-openwebui-1	0.0.0.0:3000->8080/tcp, [::]:3000->8080/tcp" qdrant=200
> ```
> (audit fail)
> (audit fail)
> (audit fail)

## Overview
Short purpose of this document in the AI local stack (GPU + LiteLLM Router + Ollama + OpenWebUI + Qdrant). Keep it concise and actionable.

## Architecture Context
- Router (ports 4000/4001), hybrids: code/docs/search → fallback openai/gpt-5  
- Local models via Ollama (qwen2.5-coder:14b etc.)
- OpenWebUI as OpenAI-compatible client  
- Vector store: Qdrant

## Operations (Terminal-only)
- Health: `ai_gateway/WAIT_HEALTH.sh`  
- Smoke: `ai_gateway/SMOKE_NOW.sh`  
- Final audit: `ai_gateway/FINAL_AUDIT.sh`

## How to Use
Step-by-step relevant to this document. Example requests, env vars, compose overlays.

## Troubleshooting
Common pitfalls + quick commands.

## Legacy Notes
(Original content preserved below)

----
## Legacy Notes (raw)

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
