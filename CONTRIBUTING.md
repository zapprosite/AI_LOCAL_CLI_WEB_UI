Contributing Guide

Prerequisites (Ubuntu 24.04)

- Docker 24+ with Compose v2 (`docker compose`)
- Bash, and either `curl` or `wget`

Validate Compose

- Resolve combined config (from repo root):
  `docker compose -f ai_gateway/docker-compose.stack.yml -f ai_gateway/docker-compose.pins.yml -f ai_gateway/docker-compose.health.yml config`

Run health and smoke tests

1) Create external network (first time):
   `docker network create ai_stack_net || true`
2) Start services:
   `cd ai_gateway && cp .env.example .env`
   `docker compose -f docker-compose.stack.yml -f docker-compose.pins.yml -f docker-compose.health.yml up -d`
3) Wait + smoke:
   `./WAIT_HEALTH.sh`
   `./SMOKE_NOW.sh`

Testing notes (logs)

- Logs and run artifacts live under `_logs/` and are ephemeral.
- Read and purge safely using:
  - `_logs/READ_AND_PURGE.sh /data/stack/_logs/<file>`
  - Preview: `MAX_LINES=200 _logs/READ_AND_PURGE.sh /data/stack/_logs/<file>`
- See `docs/LOGGING_POLICY.md` for details. Never commit contents of `_logs/`.

PR checklist

- Small, focused diff; one scope per PR
- No changes to volume mount paths under `/data/...` unless explicitly required and documented
- CI green: lint + compose config (and smoke when labeled)
- Link relevant context (PRD, TODOs) from `docs/INDEX.md`

Secrets and environment files

- Do not commit `.env` files anywhere in the repo. CI enforces this and will fail if any `.env` is tracked.
- Keep `.env.example` under version control for required variables.
- Runtime data under `/data/` must not be versioned.

License

Contributions are accepted under the project’s MIT License. See the `LICENSE` file at the repository root.
