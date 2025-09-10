## Overview

This repository provides a minimal, reproducible runtime for a local AI chat/coding stack. It is terminal-first and uses Docker Compose to orchestrate:
- `ollama` for local model execution
- `litellm` as an OpenAI-compatible gateway over Ollama
- `openwebui` for a simple web UI
- `qdrant` (optional) for vector search/RAG

Requirements: Docker 24+ with Compose v2 (the `docker compose` subcommand).

## Services

- ollama
  - Local model server exposed on `11434`. Stores model blobs and cache under `/root/.ollama`. Images are pinned in `ai_gateway/docker-compose.pins.yml` for reproducibility.

- litellm
  - OpenAI-compatible gateway on `4000`, exposing `/v1/*` endpoints. Uses `ai_gateway/config/litellm-config.yaml` to map aliases like `fast`, `light`, and `heavy` to concrete Ollama models. Requires `LITELLM_MASTER_KEY` in `ai_gateway/.env` for authenticated requests.

- openwebui
  - Web UI bound to host port `3000` (container listens on `8080`). Points to Ollama via `OLLAMA_BASE_URL=http://ollama:11434`. Persists application data under `/data/openwebui`.

- qdrant (optional)
  - Vector database on `6333` with `/readyz` health endpoint. Can be disabled by removing the service from the stack, or kept for RAG workflows with persistent data under `/data/qdrant`.

## Volumes

- `/data/ollama` → `/root/.ollama` (Ollama models and cache)
- `/data/openwebui` → `/app/backend/data` (OpenWebUI data)
- `/data/qdrant` → `/qdrant/storage` (Qdrant storage)

## Network

- External Docker network: `ai_stack_net`
  - Create once: `docker network create ai_stack_net || true`

## Healthchecks

The stack defines container healthchecks; the helper `ai_gateway/WAIT_HEALTH.sh` waits until:
- ollama: `GET http://127.0.0.1:11434/api/tags` returns HTTP 200
- litellm: `GET http://127.0.0.1:4000/v1/models` returns HTTP 200 (use `Authorization: Bearer ${LITELLM_MASTER_KEY}` when set)
- openwebui: `GET http://127.0.0.1:3000` returns HTTP 200
- qdrant: `GET http://127.0.0.1:6333/readyz` returns HTTP 200

## How to Run

From the repository root:

```bash
# 1) Ensure external network exists (first time only)
docker network create ai_stack_net || true

# 2) Prepare environment
cp ai_gateway/.env.example ai_gateway/.env

# 3) Start the stack (no build)
docker compose \
  -f ai_gateway/docker-compose.stack.yml \
  -f ai_gateway/docker-compose.pins.yml \
  -f ai_gateway/docker-compose.health.yml \
  up -d

# 4) Wait for health and run smoke checks
ai_gateway/WAIT_HEALTH.sh
ai_gateway/SMOKE_NOW.sh

# 5) Optional teardown when finished
docker compose \
  -f ai_gateway/docker-compose.stack.yml \
  -f ai_gateway/docker-compose.pins.yml \
  -f ai_gateway/docker-compose.health.yml \
  down -v
```

## Troubleshooting

- Missing external network
  - Create it: `docker network create ai_stack_net`

- litellm unhealthy or unauthorized
  - Confirm config is loaded and port bound: `curl -s -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" http://127.0.0.1:4000/v1/models | jq`
  - Ensure `.env` exists at `ai_gateway/.env` with `LITELLM_MASTER_KEY`.

- openwebui not responding on 3000
  - Check mapping `3000:8080`: `curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:3000` (expect `200`).

- qdrant not healthy
  - Verify: `curl -s http://127.0.0.1:6333/readyz` (expect `ok` or HTTP 200).

- Inspect compose state and logs
  - Status: `docker compose -f ai_gateway/docker-compose.stack.yml -f ai_gateway/docker-compose.pins.yml -f ai_gateway/docker-compose.health.yml ps`
  - Logs (last 200): `docker compose -f ai_gateway/docker-compose.stack.yml -f ai_gateway/docker-compose.pins.yml -f ai_gateway/docker-compose.health.yml logs --tail=200`

- Log retention and safe reading
  - See `docs/LOGGING_POLICY.md` for ephemeral log policy and how to use `_logs/READ_AND_PURGE.sh` safely.

## License

This project is released under the MIT License. See the `LICENSE` file at the repository root for full terms.
