#!/usr/bin/env bash
set -Eeuo pipefail

# =========================================
# Bootstrap único: ENV + Git + Overlays + Checks
# =========================================

# ---- Pastas base ----
sudo install -d -m 0755 /data/stack/{_out,.git-hooks,scripts}
sudo install -d -m 0755 /data/stack/ai_gateway/{docs,scripts}
sudo install -d -m 0755 /data/stack/ai_gateway/config

# ---- .env (runtime) ----
cat > /data/stack/ai_gateway/.env <<'EOF_ENV'
# === Runtime env (usado pelo Docker Compose na pasta ai_gateway) ===
# Projeto/Networks
COMPOSE_PROJECT_NAME=ai_gateway
AI_STACK_NET=ai_stack_net

# Portas locais (host)
OLLAMA_PORT=11434
LITELLM_PORT=4000
QDRANT_PORT=6333
OPENWEBUI_PORT=3000

# Endpoints internos (entre containers)
OLLAMA_BASE_URL=http://ollama:11434
QDRANT_URL=http://qdrant:6333

# LiteLLM
LITELLM_CONFIG=/config/litellm-config.yaml
LITELLM_DISABLE_TELEMETRY=1
NO_PROXY=localhost,127.0.0.1,ollama,qdrant
no_proxy=localhost,127.0.0.1,ollama,qdrant

# [OPCIONAL] Provedores remotos (NÃO COMMITAR .env)
#OPENAI_API_KEY=__preencher_se_for_usar_remoto__
EOF_ENV

# ---- .env.example (modelo seguro p/ commit) ----
cat > /data/stack/ai_gateway/.env.example <<'EOF_ENVX'
# Copie para .env e ajuste conforme necessário (não commitar chaves).
COMPOSE_PROJECT_NAME=ai_gateway
AI_STACK_NET=ai_stack_net
OLLAMA_PORT=11434
LITELLM_PORT=4000
QDRANT_PORT=6333
OPENWEBUI_PORT=3000
OLLAMA_BASE_URL=http://ollama:11434
QDRANT_URL=http://qdrant:6333
LITELLM_CONFIG=/config/litellm-config.yaml
LITELLM_DISABLE_TELEMETRY=1
NO_PROXY=localhost,127.0.0.1,ollama,qdrant
no_proxy=localhost,127.0.0.1,ollama,qdrant
#OPENAI_API_KEY=__coloque_sua_chave_ou_remova_se_nao_usar__
EOF_ENVX

# ---- .gitignore (repo root) ----
cat > /data/stack/.gitignore <<'EOF_GI'
# === ENV / Segredos ===
ai_gateway/.env
**/.env
!**/.env.example
*.secret
*.key
*.pem

# === Artefatos e logs ===
/_out/
/**/_out/
**/*.log
**/tmp/
**/.cache/

# === Python ===
**/__pycache__/
**/.pytest_cache/
**/.mypy_cache/
**/*.pyc

# === Docker/Build ===
**/.docker/
**/docker-data/
**/.DS_Store

# === Node/NPM ===
**/node_modules/
**/dist/
**/build/
EOF_GI

# ---- .gitattributes ----
cat > /data/stack/.gitattributes <<'EOF_GA'
* text=auto eol=lf
EOF_GA

# ---- Overlay do Compose para ler .env nas portas/vars ----
cat > /data/stack/ai_gateway/docker-compose.env.overlay.yml <<'EOF_OV'
services:
  ollama:
    ports:
      - "${OLLAMA_PORT:-11434}:11434"
    environment:
      - NO_PROXY=${NO_PROXY}
      - no_proxy=${no_proxy}

  litellm:
    ports:
      - "${LITELLM_PORT:-4000}:4000"
    environment:
      - LITELLM_CONFIG=${LITELLM_CONFIG}
      - LITELLM_DISABLE_TELEMETRY=${LITELLM_DISABLE_TELEMETRY}
      - NO_PROXY=${NO_PROXY}
      - no_proxy=${no_proxy}

  qdrant:
    ports:
      - "${QDRANT_PORT:-6333}:6333"

  openwebui:
    ports:
      - "${OPENWEBUI_PORT:-3000}:8080"
    environment:
      - OLLAMA_BASE_URL=${OLLAMA_BASE_URL}
EOF_OV

# ---- Script: aplicar .env + overlay e reiniciar stack ----
cat > /data/stack/scripts/env_apply_restart.sh <<'EOF_APPLY'
#!/usr/bin/env bash
set -Eeuo pipefail

GWD="/data/stack/ai_gateway"
ENVF="${GWD}/.env"
BASE="${GWD}/docker-compose.stack.yml"
OVLY="${GWD}/docker-compose.env.overlay.yml"

echo "== 1/4 Validando .env e overlays =="
[ -s "$ENVF" ] || { echo "ERRO: $ENVF ausente/vazio"; exit 1; }
[ -s "$BASE" ] || { echo "ERRO: compose base ausente em $BASE"; exit 1; }
[ -s "$OVLY" ] || { echo "ERRO: overlay ausente em $OVLY"; exit 1; }

echo "== 2/4 Compose config (expansão de vars) =="
docker compose --env-file "$ENVF" -f "$BASE" -f "$OVLY" config | sed -n '1,80p' || true
echo

echo "== 3/4 Subindo stack com .env (idempotente) =="
cd "$GWD"
docker compose --env-file "$ENVF" -f "$BASE" -f "$OVLY" up -d --remove-orphans
docker compose --env-file "$ENVF" -f "$BASE" -f "$OVLY" ps

echo "== 4/4 Checagem rápida de portas =="
for p in "${OLLAMA_PORT:-11434}" "${LITELLM_PORT:-4000}" "${QDRANT_PORT:-6333}" "${OPENWEBUI_PORT:-3000}"; do
  nc -z 127.0.0.1 "$p" && echo "PORT OK $p" || echo "PORT FAIL $p"
done
EOF_APPLY

# ---- Script: checagem de ENV + Compose + portas ----
cat > /data/stack/scripts/env_check.sh <<'EOF_ENVCHK'
#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/data/stack"
GWD="/data/stack/ai_gateway"
ENV_FILE="${GWD}/.env"
COMPOSE_FILE="${GWD}/docker-compose.stack.yml"

echo "== 1/5 Verificando .env existente =="
[ -s "${ENV_FILE}" ] || { echo "ERRO: ${ENV_FILE} ausente ou vazio"; exit 1; }
grep -v '^OPENAI_API_KEY=' "${ENV_FILE}" | sed -n '1,80p' || true
echo

echo "== 2/5 Validação do Compose com .env =="
docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" config | sed -n '1,80p' || true
echo

echo "== 3/5 Checando que .env está ignorado no Git =="
cd "${ROOT}"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "WARN: ${ROOT} não é repo Git"; exit 0; }
git check-ignore -v ai_gateway/.env || echo "WARN: .env não está ignorado (verifique .gitignore)"
echo

echo "== 4/5 Ensaios de variáveis críticas =="
awk -F= '/^(COMPOSE_PROJECT_NAME|AI_STACK_NET|OLLAMA_BASE_URL|QDRANT_URL|LITELLM_CONFIG|NO_PROXY|no_proxy)=/ {print "OK " $1 "=" $2}' "${ENV_FILE}" || true
echo

echo "== 5/5 Sanidade leve =="
for p in "${OLLAMA_PORT:-11434}" "${LITELLM_PORT:-4000}" "${QDRANT_PORT:-6333}" "${OPENWEBUI_PORT:-3000}"; do
  nc -z 127.0.0.1 "$p" && echo "PORT OK $p" || echo "PORT FAIL $p"
done
EOF_ENVCHK

# ---- Hook Git: pre-commit (bloqueia .env/segredos/arquivos grandes) ----
cat > /data/stack/.git-hooks/pre-commit <<'EOF_HOOK'
#!/usr/bin/env bash
set -Eeuo pipefail

fail=0
PATTERNS='(^|/)\.env$|\.secret$|\.pem$|\.key$'
while IFS= read -r -d '' f; do
  if [[ "$f" =~ $PATTERNS ]]; then
    echo "ERRO: arquivo proibido no commit: $f"
    fail=1
  fi
done < <(git diff --cached --name-only -z)

while IFS= read -r -d '' f; do
  size=$(stat -c%s "$f" 2>/dev/null || echo 0)
  if [ "$size" -gt $((20*1024*1024)) ]; then
    echo "ERRO: arquivo grande (>20MB) staged: $f ($size bytes)"
    fail=1
  fi
done < <(git diff --cached --name-only -z)

if [ "$fail" -ne 0 ]; then
  echo "Commit abortado pelo pre-commit hook."
  exit 1
fi
exit 0
EOF_HOOK
chmod +x /data/stack/.git-hooks/pre-commit

# ---- Script: instalar hooks e bootstrap Git ----
cat > /data/stack/scripts/git_hooks_install.sh <<'EOF_GIT'
#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="/data/stack"
HOOKS="${ROOT}/.git-hooks"

echo "== 1/3 Git init (idempotente) =="
if git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  echo "Repo já existe em $ROOT"
else
  git -C "$ROOT" init -b main
  git -C "$ROOT" config user.name "stack-bot"
  git -C "$ROOT" config user.email "stack-bot@example.local"
fi
git -C "$ROOT" config --local safe.directory "$ROOT"

echo "== 2/3 Ativar hooks customizados =="
git -C "$ROOT" config core.hooksPath "$HOOKS"
echo "Hooks ativos em: $(git -C "$ROOT" config core.hooksPath)"

echo "== 3/3 Verificar ignore =="
git -C "$ROOT" check-ignore -v ai_gateway/.env || echo "INFO: .env fora do index (ok se não adicionado)"
EOF_GIT

# ---- Doc curta ----
cat > /data/stack/ai_gateway/docs/ENV_AND_GIT.md <<'EOF_DOC'
# ENV & Git – Fluxo Rápido

1. Edite `ai_gateway/.env` (portas e URLs). **Nunca** commitar `.env`.
2. Aplique com overlay:
   `/data/stack/scripts/env_apply_restart.sh`
3. Git:
   - `.gitignore` ignora `.env`.
   - Hook `pre-commit` bloqueia `.env`, `*.secret`, `*.key`, `*.pem` e arquivos > 20MB.
4. Verifique:
   `docker compose --env-file ai_gateway/.env -f ai_gateway/docker-compose.stack.yml -f ai_gateway/docker-compose.env.overlay.yml config`
EOF_DOC

# ---- Permissões executáveis ----
chmod +x /data/stack/scripts/env_apply_restart.sh
chmod +x /data/stack/scripts/env_check.sh
chmod +x /data/stack/scripts/git_hooks_install.sh

echo "Bootstrap concluído: arquivos escritos."
