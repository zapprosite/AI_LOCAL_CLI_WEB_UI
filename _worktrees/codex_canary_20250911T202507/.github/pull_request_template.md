## Objective
Describe the change and the expected outcome.

## Changes
- [ ] Compose updates
- [ ] LiteLLM config
- [ ] Scripts (UP/STATUS/SMOKE/WAIT_HEALTH)
- [ ] Docs (README/PRD)

## Validation
- [ ] docker compose config OK
- [ ] WAIT_HEALTH.sh OK
- [ ] SMOKE_NOW.sh PASS
- [ ] CHAT_MATRIX.sh PASS (fast/light/heavy)

## Risks & Rollback
- [ ] Low/Medium/High
- [ ] Rollback: `docker compose down -v && git revert`

## References

- [README](../README.md) — ops-first runbook
- [CONTRIBUTING](../CONTRIBUTING.md) — local validation steps
- [Docs Index](../docs/INDEX.md)
- [Branch Policy](../docs/BRANCH_POLICY.md)
- [Logging Policy](../docs/LOGGING_POLICY.md)
- [Archive Policy](../docs/ARCHIVE_POLICY.md)
- [License](../LICENSE)

### CI Workflows

- Lint: [.github/workflows/lint.yml](../.github/workflows/lint.yml)
- Compose Config: [.github/workflows/compose.yml](../.github/workflows/compose.yml)
- Smoke (DinD): [.github/workflows/smoke.yml](../.github/workflows/smoke.yml)

### Health & Smoke Scripts

- Wait until healthy: [ai_gateway/WAIT_HEALTH.sh](../ai_gateway/WAIT_HEALTH.sh)
- Smoke tests: [ai_gateway/SMOKE_NOW.sh](../ai_gateway/SMOKE_NOW.sh)

### Compose Files

- Stack: [ai_gateway/docker-compose.stack.yml](../ai_gateway/docker-compose.stack.yml)
- Pins: [ai_gateway/docker-compose.pins.yml](../ai_gateway/docker-compose.pins.yml)
- Health: [ai_gateway/docker-compose.health.yml](../ai_gateway/docker-compose.health.yml)

### Keep Lists

- Root: [KEEP_ROOT.list](../KEEP_ROOT.list)
- Gateway: [ai_gateway/KEEP_AIGW.list](../ai_gateway/KEEP_AIGW.list)
- Docs: [docs/KEEP_DOCS.list](../docs/KEEP_DOCS.list)

### Logs Helper

- Read & purge: [_logs/READ_AND_PURGE.sh](../_logs/READ_AND_PURGE.sh)
