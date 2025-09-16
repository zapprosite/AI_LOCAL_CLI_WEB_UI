#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/data/stack"

echo "== 1/4 Git init (idempotente) =="
if git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  echo "Repo já existe em $ROOT"
else
  git -C "$ROOT" init -b main
  git -C "$ROOT" config user.name "stack-bot"
  git -C "$ROOT" config user.email "stack-bot@example.local"
fi
git -C "$ROOT" config --local safe.directory "$ROOT"

echo "== 2/4 Garantir _out/ e .gitkeep =="
mkdir -p "$ROOT/_out"
touch "$ROOT/_out/.gitkeep"

echo "== 3/4 Adicionar e commitar baseline =="
git -C "$ROOT" add .gitignore .gitattributes _out/.gitkeep || true
# Não adiciona .env
git -C "$ROOT" commit -m "chore(repo): bootstrap .gitignore/.gitattributes e _out/.gitkeep" || echo "Nada a commitar"

echo "== 4/4 Verificações =="
git -C "$ROOT" status -s || true
git -C "$ROOT" check-ignore -v ai_gateway/.env || echo "WARN: ai_gateway/.env ainda não ignorado (verifique path)"
