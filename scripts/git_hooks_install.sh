#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="/data/stack"
HOOKS="${ROOT}/.git-hooks"

echo "== 1/3 Garantir repo git =="
git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 || { git -C "$ROOT" init -b main; }
git -C "$ROOT" config user.name "stack-bot"
git -C "$ROOT" config user.email "stack-bot@example.local"
git -C "$ROOT" config --local safe.directory "$ROOT"

echo "== 2/3 Ativar hooks customizados =="
chmod +x "${HOOKS}/pre-commit"
git -C "$ROOT" config core.hooksPath "$HOOKS"

echo "== 3/3 Teste de ignore e hook =="
git -C "$ROOT" check-ignore -v ai_gateway/.env || echo "INFO: .env fora do index (ok se não adicionado)"
echo "Hooks ativos em: $(git -C "$ROOT" config core.hooksPath)"
