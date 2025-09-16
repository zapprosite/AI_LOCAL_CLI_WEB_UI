# README

> **Status**: synchronized  
> **Host**: zappro
> **Last Audited**: 2025-09-16T06:00:55-03:00
> **Stack Summary**:  
> ```
> (audit fail)
> ```
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

AI Gateway — Quickstart

- Requisitos: Docker, Docker Compose, GPU NVIDIA opcional.
- Rede: `ai_stack_net` (criada automaticamente pelo `UP.sh` se não existir).

Passos:
- `cd /data/stack/ai_gateway`
- `cp .env.example .env` e ajuste portas/variáveis se necessário
- `./UP.sh` para subir (faz verificação de portas e rede)
- `./STATUS.sh` para checar endpoints:
  - Ollama: `http://127.0.0.1:11434/api/tags`
  - LiteLLM: `http://127.0.0.1:4000/v1/models` (200 ou 401 OK)
  - Open WebUI: `http://127.0.0.1:3000/`
- Para derrubar: `docker compose -f docker-compose.stack.yml down -v`

Observações:
- Compose único: `docker-compose.stack.yml` (arquivos antigos em `ai_gateway/_old/`).
- Config do LiteLLM em `ai_gateway/config/litellm-config.yaml`.
