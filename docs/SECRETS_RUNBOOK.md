# SECRETS_RUNBOOK — O que preencher (sem valores)

Preencha apenas em `/data/stack/secrets/.env` (fora do Git). Este arquivo descreve o que vai lá.

## Core
- `LITELLM_MASTER_KEY`
- `OPENAI_API_BASE` (padrão: `http://litellm_fb:4001/v1`)
- `OPENAI_API_KEY` (opcional)

## Vetores / DB
- `VECTOR_DB` (= `qdrant`)
- `QDRANT_URI` (ex: `http://qdrant:6333`)
- `QDRANT_API_KEY` (opcional)
- `POSTGRES_USER` (ex: `openwebui`)
- `POSTGRES_PASSWORD`
- `POSTGRES_DB` (ex: `openwebui`)
- `DATABASE_URL` (se vazio, será gerado pelo assistente)

## Integrações
- Google Drive: `GOOGLE_SERVICE_ACCOUNT_JSON` (Base64 do JSON da Service Account) ou use arquivo montado.
- Slack: `SLACK_BOT_TOKEN`, `SLACK_SIGNING_SECRET`
- Trello: `TRELLO_KEY`, `TRELLO_TOKEN`

## DNS/HTTPS (se usar proxy)
- `DNS_PROVIDER` (ex: `cloudflare`)
- `CF_API_TOKEN` (opcional)
