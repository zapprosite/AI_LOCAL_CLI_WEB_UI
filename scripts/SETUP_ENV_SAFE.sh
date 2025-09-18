#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="/data/stack/secrets/.env"
mkdir -p "$(dirname "$ENV_FILE")"
touch "$ENV_FILE"
chmod 600 "$ENV_FILE"

# Lê pares existentes (ignora comentários e linhas vazias)
declare -A ENV
while IFS='=' read -r k v; do
  [[ -z "${k:-}" || "${k:0:1}" = "#" ]] && continue
  ENV["$k"]="${v:-}"
done < <(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$ENV_FILE" || true)

prompt_set () {
  local key="$1"; shift
  local msg="$1"; shift
  local def="${1:-}"; shift || true
  local silent="${1:-}" # "silent" para senhas
  if [[ -n "${ENV[$key]:-}" ]]; then
    echo "[keep] $key"
    return 0
  fi
  if [[ -n "$def" ]]; then
    echo -n "[ask] $msg [$def]: "
  else
    echo -n "[ask] $msg: "
  fi
  if [[ "$silent" == "silent" ]]; then
    read -r -s val; echo
  else
    read -r val
  fi
  if [[ -z "$val" && -n "$def" ]]; then val="$def"; fi
  if [[ -z "$val" ]]; then
    echo "[skip] $key vazio; pode preencher depois."
    return 0
  fi
  echo "$key=$val" >> "$ENV_FILE"
  ENV["$key"]="$val"
  echo "[set]  $key"
}

# ==== CORE ====
prompt_set "LITELLM_MASTER_KEY" "Master key do router LiteLLM" "" "silent"
prompt_set "OPENAI_API_BASE" "Base URL do provedor OpenAI" "http://litellm_fb:4001/v1"
prompt_set "OPENAI_API_KEY" "OPENAI_API_KEY (opcional)" ""

# ==== VECTORS / DB ====
prompt_set "VECTOR_DB" "Vector DB" "qdrant"
prompt_set "QDRANT_URI" "Qdrant URI" "http://qdrant:6333"
prompt_set "QDRANT_API_KEY" "Qdrant API Key (opcional)" ""

prompt_set "POSTGRES_USER" "Postgres user" "openwebui"
prompt_set "POSTGRES_PASSWORD" "Postgres password" "" "silent"
prompt_set "POSTGRES_DB" "Postgres DB" "openwebui"

# Se faltar DATABASE_URL, gera com base nas variáveis
if [[ -z "${ENV[DATABASE_URL]:-}" ]]; then
  PUSER="${ENV[POSTGRES_USER]:-openwebui}"
  PDB="${ENV[POSTGRES_DB]:-openwebui}"
  echo -n "[info] Gerar DATABASE_URL com host 'postgres' e porta 5432? [Y/n]: "
  read -r yn
  yn="${yn:-Y}"
  if [[ "$yn" =~ ^[Yy]$ ]]; then
    if [[ -z "${ENV[POSTGRES_PASSWORD]:-}" ]]; then
      echo "[warn] POSTGRES_PASSWORD vazio — não posso gerar DATABASE_URL agora."
    else
      echo "DATABASE_URL=postgresql://${PUSER}:${ENV[POSTGRES_PASSWORD]}@postgres:5432/${PDB}" >> "$ENV_FILE"
      ENV["DATABASE_URL"]="postgresql://${PUSER}:***@postgres:5432/${PDB}"
      echo "[set]  DATABASE_URL"
    fi
  fi
else
  echo "[keep] DATABASE_URL"
fi

# ==== INTEGRATIONS (opcionais) ====
prompt_set "GOOGLE_SERVICE_ACCOUNT_JSON" "Google SA JSON (Base64) — opcional" ""
prompt_set "SLACK_BOT_TOKEN" "Slack Bot Token — opcional" ""
prompt_set "SLACK_SIGNING_SECRET" "Slack Signing Secret — opcional" ""
prompt_set "TRELLO_KEY" "Trello Key — opcional" ""
prompt_set "TRELLO_TOKEN" "Trello Token — opcional" ""

# ==== DNS/HTTPS (opcionais) ====
prompt_set "DNS_PROVIDER" "DNS Provider (ex: cloudflare) — opcional" ""
prompt_set "CF_API_TOKEN" "Cloudflare API Token — opcional" ""

echo
echo "Arquivo salvo em: $ENV_FILE"
echo "Dica: para preencher SA JSON a partir de arquivo, rode:"
echo "  base64 -w0 /caminho/drive_sa.json >> $ENV_FILE  # no valor de GOOGLE_SERVICE_ACCOUNT_JSON"
