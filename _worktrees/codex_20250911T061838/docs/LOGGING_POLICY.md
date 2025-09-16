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
