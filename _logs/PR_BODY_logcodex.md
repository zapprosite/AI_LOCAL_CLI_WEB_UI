# Aggregate PRD + Logs (logcodex.md)

This PR aggregates the PRD and the key health/audit artifacts into a single Markdown for easy audit, and adds automation for recurring checks.

## Summary
- Adds `logcodex.md` with PRD and logs (copy also on Desktop)
- Adds `CHECKUP_ALL.sh` to run WAIT/SMOKE/AUDIT, DATA_STANDARDIZE, model listings, Qdrant seeds and aggregate logs
- Adds `logs_archive.sh` to rotate `_logs/*.txt` and `_logs/logcodex_*.md` into `_archive/<ts>/...`
- Adds E2E screenshots from OpenWebUI (auth + models showing hybrids)

## Artifacts
- PRD: `docs/specs/PRD_MAP_TEST_DEBUG.md`
- Aggregated: `_logs/logcodex.md`
- Health: `_logs/wait.txt` | `_logs/smoke.txt` | `_logs/audit.txt`
- Models: `_logs/models_4000.txt` | `_logs/models_4001.txt`
- Qdrant seed: `_logs/qdrant_seed.txt`
- GPU/Ollama: `_logs/nvidia_smi.txt` | `_logs/ollama_tail.txt`
- Screenshots: `_logs/openwebui_auth.png` | `_logs/openwebui_models_hybrid.png`

## Automation
- Orchestrator: `scripts/CHECKUP_ALL.sh`
- Logs governance: `scripts/logs_archive.sh`
- Cron (hourly): runs `CHECKUP_ALL.sh`, writes `_logs/checkup_cron.log`

## Validation
- Hybrids exposed on :4001: `code.hybrid`, `docs.hybrid`, `search.hybrid`
- OpenWebUI configured to use fallback router; selector shows hybrids
- Qdrant seeds created: `agents_kb`, `docs_kb`

## Notes
- OpenWebUI admin password was reset locally to complete login for E2E; update it if needed.
