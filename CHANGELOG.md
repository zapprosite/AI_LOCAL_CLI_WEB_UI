## [1.0.1] - 2025-09-11

### Documentation
- add CHANGELOG 1.0.0 and release process in CONTRIBUTING (d7044f5)

# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2025-09-11

### Features
- Compose stack with pinned image digests (`ai_gateway/docker-compose.pins.yml`).
- Health overlay and hardened health probes for services (ollama, litellm, openwebui, qdrant).
- CI workflows:
  - Lint (`yamllint`, `shellcheck`) with matrix and caches.
  - Compose config validation (matrix across base and healthfix overlays).
  - Smoke (DinD) end-to-end and split per-service smoke.
  - Weekly image digest refresh with automated PRs.
  - Secrets scanning via gitleaks (excludes `_archive/` and `_logs/`).
- Docs: clear policies and indexes
  - README with ops-first sections and troubleshooting.
  - `docs/INDEX.md` as documentation entrypoint.
  - Logging policy (`docs/LOGGING_POLICY.md`).
  - Archive policy (`docs/ARCHIVE_POLICY.md`).
  - Branch policy with rollback recipe (`docs/BRANCH_POLICY.md`).
  - Contributing guide with local runbook and release notes.
- Security and governance:
  - CI guard to block committed `.env` files; `.gitignore` updated to exclude `/data/`.
  - CODEOWNERS enforcing maintainer review on `ai_gateway/**`, `docs/**`, `.github/workflows/**`.

### Scripts & Tooling
- `scripts/UPDATE_DIGESTS.sh` — refresh pinned image digests to latest for their tags.
- `scripts/ROLLBACK_GREEN.sh` — automate rollback branches to green anchor commit.

### Notes
- Conventional commits are adopted for commit messages.
- SemVer is used for versioning. This tag marks the first stable baseline.

