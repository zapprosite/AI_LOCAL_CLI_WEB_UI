#!/usr/bin/env bash
set -euo pipefail

echo "=== AUDIT: existentes ==="
command -v node  && node -v  || echo "node: not found"
command -v npm   && npm -v   || echo "npm: not found"
command -v pnpm  && pnpm -v  || echo "pnpm: not found"
command -v corepack && corepack --version || echo "corepack: not found"
command -v volta && volta --version || echo "volta: not found"
grep -E 'NVM_DIR|nvm.sh' -n ~/.bashrc ~/.zshrc 2>/dev/null || true

echo "=== INSTALL: Volta ==="
if ! command -v volta >/dev/null; then
  curl -fsSL https://get.volta.sh | bash
fi

# recarrega PATH do Volta se disponível
export VOLTA_HOME="$HOME/.volta"
[ -d "$VOLTA_HOME/bin" ] && export PATH="$VOLTA_HOME/bin:$PATH"

echo "=== PIN: Node 22 LTS ==="
volta install node@22
volta pin node@22

echo "=== ENABLE: Corepack + pnpm ==="
corepack enable
corepack enable pnpm
corepack prepare pnpm@latest-10 --activate

echo "=== RESULT ==="
which node; node -v
which npm; npm -v
which pnpm; pnpm -v
which corepack; corepack --version
