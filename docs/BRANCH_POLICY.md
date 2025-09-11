Branch and PR Policy

- Small PRs only: keep changes focused and reviewable.
- CI gates must pass: lint, compose config; smoke optional unless labeled.
- Branching model: feature branches off `main`; prefer rebase for short-lived work.

Create a feature branch

```bash
git checkout main
git pull --ff-only
git checkout -b feat/<scope>
# ... do work, commit, push and open PR ...
```

Green anchor commit

- Anchor message: `feat: V1 stable (compose+pins+health+smoke)`
- Find it and use it for rollbacks/hotfixes.

Rollback recipe (copy/paste)

```bash
# Find the green commit anchor
GOOD=$(git log --grep -F 'feat: V1 stable (compose+pins+health+smoke)' -n1 --format=%H)

# Save current HEAD on a rescue branch (for investigation)
git checkout -B rescue/$(date +%Y%m%dT%H%M%S) HEAD

# Create a restore branch pinned to the green anchor
git checkout -B chore/runtime-restore "$GOOD"

# Push and open a PR that restores runtime to the green state
git push -u origin chore/runtime-restore
```

Automation

- Prefer using the helper script when available:

```bash
scripts/ROLLBACK_GREEN.sh
```

- The script creates a rescue branch from current HEAD and a `chore/runtime-restore` branch from the green anchor, then prints next steps to push and verify.

Hotfix flow

```bash
# Branch from the green anchor for minimal fix
GOOD=$(git log --grep -F 'feat: V1 stable (compose+pins+health+smoke)' -n1 --format=%H)
git checkout -B fix/<scope>-from-green "$GOOD"
# ... apply minimal fix, validate, then PR ...
```
