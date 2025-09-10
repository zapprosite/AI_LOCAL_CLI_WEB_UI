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
