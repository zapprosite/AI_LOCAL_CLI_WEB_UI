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
