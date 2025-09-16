# Repository Guidelines

## Project Structure & Module Organization
- `ai_gateway/`: Core stack (Docker Compose, `.env`, `config/`, `UP.sh`, `STATUS.sh`, smoke scripts).
- `scripts/`: Host utilities for health checks, environment, and diagnostics.
- `docs/`: Operational docs (`README.md`, `PRD_FINAL.md`).
- `apps/starter-nextjs/`: Minimal Next.js sample (`src/app/...`).
- `_labs/`: Experimental code (LangGraph JS/Python, examples). Not production-critical.

## Build, Test, and Development Commands
- Start stack: `cd ai_gateway && cp .env.example .env && ./UP.sh`
  - Alternative: `docker compose -f docker-compose.stack.yml up -d`
- Status/health: `ai_gateway/STATUS.sh` (ps + endpoint checks)
- Smoke test: `ai_gateway/stack_smoke_v1.sh` (Ollama tags, `/v1/models`, chat)
- Stop: `docker compose -f ai_gateway/docker-compose.stack.yml down -v`

## Coding Style & Naming Conventions
- Shell: `#!/usr/bin/env bash` + `set -euo pipefail`; 2-space indent; quote variables; snake_case filenames (e.g., `stack_health.sh`).
- YAML/Compose: 2-space indent; single source of truth is `ai_gateway/docker-compose.stack.yml`; load config via `.env` and `config/`.
- TypeScript (Next.js): place routes under `src/app/...` (e.g., `api/health/route.ts`).
- General: small, idempotent scripts; avoid destructive defaults; prefer explicit flags.

## Testing Guidelines
- Primary: run `ai_gateway/stack_smoke_v1.sh` after changes; it validates ports, `/api/tags`, and `/v1/models`.
- Health sweep: `scripts/stack_health.sh` (host + container checks).
- Labs (optional):
  - JS agents: `cd _labs/stack_v1/agents/js && pnpm i && pnpm test`
  - Python service: `cd _labs/stack_v1/services/python && uv run pytest` (if tests are added)

## Commit & Pull Request Guidelines
- Commits: Conventional style — `feat:`, `fix:`, `docs:`, `chore:`, `ci:`. Example: `feat(ai_gateway): add LiteLLM healthcheck`.
- Branches: `feat/stack-root/<scope>` or `fix/ai-gateway/<scope>`.
- PRs include: goal, summary of changes, validation steps (commands/logs), rollback plan, and links to relevant docs.
- Secrets: never commit `.env` (already ignored). Redact tokens in logs/screenshots.
- Documentation: update `docs/README.md` and `docs/PRD_FINAL.md` when behavior or interfaces change.

## Security & Configuration Tips
- Put all secrets in `ai_gateway/.env`; keep `LITELLM_MASTER_KEY` and any cloud keys private.
- Volumes map to `/data/...`; ensure `ai_stack_net` exists (created by `UP.sh`).
- For LiteLLM models, adjust `ai_gateway/config/litellm-config.yaml` or set model envs to match local Ollama tags.
