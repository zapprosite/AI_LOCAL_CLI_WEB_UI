#!/usr/bin/env bash
set -Eeuo pipefail

# Objetivo: remover chaves expostas de histórico e arquivos; auditar ocorrências.
# Alvos e padrões seguros (ajuste se necessário):
ROOTS=(
  "/home/$USER"
  "/data/stack"
)
PATTERNS=('sk-' 'sk_live_' 'sk-proj-' 'OPENAI_API_KEY=' 'Authorization: Bearer ')

echo "== 1/4: Congelar histórico atual =="
# Garante que comandos seguintes não gravem no histórico
export HISTFILE="$HOME/.bash_history"
set +o history || true

echo "== 2/4: Remover linhas do histórico contendo padrões sensíveis =="
if [ -f "$HISTFILE" ]; then
  cp -f "$HISTFILE" "$HISTFILE.bak.$(date -u +%Y%m%dT%H%M%SZ)"
  TMP="$(mktemp)"
  cp -f "$HISTFILE" "$TMP"
  for p in "${PATTERNS[@]}"; do
    # remove linhas que contenham o padrão (fixstrings)
    grep -Fv "$p" "$TMP" > "${TMP}.2" || true
    mv -f "${TMP}.2" "$TMP"
  done
  mv -f "$TMP" "$HISTFILE"
  # Limpa histórico da sessão atual (se estiver ativo)
  history -c 2>/dev/null || true
  history -w 2>/dev/null || true
  echo "Histórico limpo. Backup: $HISTFILE.bak.*"
else
  echo "Sem arquivo de histórico em $HISTFILE"
fi

echo "== 3/4: Busca por vazamentos em arquivos (texto) =="
FOUND=0
for base in "${ROOTS[@]}"; do
  [ -d "$base" ] || continue
  # Grep em texto; ignora binários; lista até 200 acertos por padrão
  if grep -R -n --binary-files=without-match --fixed-strings \
    -e 'sk-' -e 'sk_live_' -e 'sk-proj-' -e 'OPENAI_API_KEY=' -e 'Authorization: Bearer ' \
    "$base" 2>/dev/null | head -n 200; then
    FOUND=1
  fi
done
if [ "$FOUND" -eq 0 ]; then
  echo "OK: nenhum vazamento textual encontrado nos diretórios alvos."
else
  echo "ATENÇÃO: há ocorrências listadas acima. Remova/rotate conforme necessário."
fi

echo "== 4/4: Sanitizar variáveis de ambiente desta sessão =="
unset OPENAI_API_KEY API_KEY || true
echo "Concluído."
