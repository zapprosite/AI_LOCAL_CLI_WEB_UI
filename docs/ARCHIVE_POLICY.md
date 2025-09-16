# ARCHIVE_POLICY

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

Archive Policy

- Location: `_archive/`
- Purpose: park non‑essential, deprecated, or bulky artifacts outside the active runtime
- Tools: `stack_minify_v1.sh` and `stack_clean_by_keep.sh` move items automatically based on keep lists
- Git: `_archive/` is ignored by `.gitignore` to avoid large binary churn

What goes to _archive

- Generated or bulky artifacts that are not required to run the stack (e.g., ad‑hoc diagnostics, temporary exports, old compose snapshots)
- Experimental/lab code and one‑off scripts that should not ship in production layout
- Obsolete configs or overlays superseded by the current stack
- Non‑critical backups taken before refactors

Keep lists and automation

- Root keep list: `KEEP_ROOT.list` defines files/folders that must remain in the working tree
- ai_gateway keep list: `ai_gateway/KEEP_AIGW.list` protects gateway essentials
- docs keep list: `docs/KEEP_DOCS.list` pins canonical docs
- The cleaner scripts read these lists and move everything else into a timestamped folder under `_archive/`

Restore procedure (from _archive back to active)

1) Identify the snapshot
   - Browse `_archive/` for the relevant timestamped directory (e.g., `_archive/20250910T055709/...`).
2) Inspect before restore
   - Review contents and ensure you are not restoring secrets or stale configs.
3) Restore the file(s)
   - Minimal: copy back the needed paths to their original locations, preserving structure:
     - `cp -a _archive/2025YYYYTMMDDHHMMSS/path/to/file ai_gateway/path/to/file`
   - Or use Git if the item is still tracked historically: `git checkout <commit> -- path/to/file`
4) Validate locally
   - For compose/configs, run: `docker compose -f ai_gateway/docker-compose.stack.yml -f ai_gateway/docker-compose.pins.yml -f ai_gateway/docker-compose.health.yml config`
   - Bring services up only after config resolves cleanly.
5) Commit restore
   - Open a small PR describing what was restored and why, and link to evidence (config output, health/smoke results).

PR hygiene (never delete in place)

- Do not hard‑delete files in active areas; move them to `_archive/` with a UTC timestamped path so history is obvious and reversible.
- Suggested pattern when moving by hand (preserves Git history):
  - `ts=$(date -u +%Y%m%dT%H%M%SZ)`
  - `mkdir -p _archive/$ts/path/to`
  - `git mv path/to/file _archive/$ts/path/to/file`
- Prefer a single snapshot per refactor instead of spreading duplicates across many timestamps.

Notes

- Secrets must never be archived; keep them out of the repository entirely.
- If an archived item is needed long‑term, consider documenting its rationale in `docs/` and restoring only the minimal subset.
