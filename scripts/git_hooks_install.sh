#!/usr/bin/env bash
set -euo pipefail
cd /data/stack
mkdir -p .git/hooks
cat > .git/hooks/pre-commit <<'H'
#!/usr/bin/env bash
set -euo pipefail
echo "[hook] DOCPOLICY…"
./scripts/DOCPOLICY.sh
echo "[hook] CI_LOCAL smoke/audit (rápido)…"
./scripts/CI_LOCAL.sh >/dev/null || { echo "pre-commit FAIL: CI_LOCAL"; exit 1; }
echo "[hook] OK"
H
chmod +x .git/hooks/pre-commit
echo "HOOKS_OK"
