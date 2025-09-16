# LOGGING_POLICY

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

Logging Policy

- Location: `_logs/`
- Purpose: store ephemeral run artifacts (compose configs, smoke outputs, diagnostics)
- Retention: ephemeral — files are deleted immediately after being read

Safety and scope

- `_logs/` is excluded by `.gitignore`; never commit its contents.
- The purge helper validates that targets are inside `/data/stack/_logs` and refuses anything outside.
- Avoid placing secrets in logs. Do not echo API keys, tokens, or credentials. Prefer redaction.

READ_AND_PURGE helper

- Script: `_logs/READ_AND_PURGE.sh`
- Behavior: prints the contents of the specified file(s) and then deletes them.
- Usage:
  - Print and purge one or more files:
    - `_logs/READ_AND_PURGE.sh /data/stack/_logs/compose_resolved_now.yaml`
    - `_logs/READ_AND_PURGE.sh /data/stack/_logs/last_smoke_after_apply.txt /data/stack/_logs/compose_ps_after_apply.txt`
  - Preview only first N lines before purge:
    - `MAX_LINES=200 _logs/READ_AND_PURGE.sh /data/stack/_logs/compose_resolved_now.yaml`
- Notes:
  - The script uses `realpath` and a prefix check to enforce the `_logs` path.
  - If you need to retain a log, copy it elsewhere before running the helper:
    - `cp /data/stack/_logs/compose_resolved_now.yaml /tmp/compose_snapshot.yaml`
  - Typical producers: `docker compose ... logs`, health/smoke scripts, diagnostics.
