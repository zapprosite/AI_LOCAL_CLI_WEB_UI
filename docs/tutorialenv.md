# Tutorial de Instalação de Chaves e Variáveis (.env)

Local padrão
- Arquivo de segredos (fora do Git): `/data/stack/secrets/.env`
- Assistente idempotente: `/data/stack/scripts/SETUP_ENV_SAFE.sh` (preenche apenas o que faltar)
- Overlay para injeção nos containers: `ai_gateway/docker-compose.env.yml`

Como abrir o assistente
- Duplo clique no atalho Desktop “Preencher Segredos (Stack)”, ou
- CLI: `bash /data/stack/scripts/SETUP_ENV_SAFE.sh`

Boas práticas
- Permissões: `chmod 600 /data/stack/secrets/.env`
- Não versionar segredos. Use `.env.example` como referência.
- Rotacionar chaves sensíveis periodicamente.

## 1) Core (LiteLLM / OpenAI)

1.1 `LITELLM_MASTER_KEY` (obrigatório)
- Geração (32 hex): `openssl rand -hex 16`
- Exemplo de inclusão no `.env`:
  ```
  LITELLM_MASTER_KEY=sk-<aleatorio>
  ```
- Verificação (lista modelos híbridos):
  ```bash
  KEY=$(awk -F= '/^LITELLM_MASTER_KEY=/{print $2}' /data/stack/secrets/.env)
  curl -s -H "Authorization: Bearer $KEY" http://127.0.0.1:4001/v1/models | jq -r '.data[]?.id' | head
  ```

1.2 `OPENAI_API_BASE` (opcional para provider externo)
- Padrão local: `http://litellm_fb:4001/v1` (usado pela UI via overlay)
- Defina quando quiser usar provedores externos compatíveis com OpenAI.

1.3 `OPENAI_API_KEY` (opcional)
- Só necessário se usar provedores externos (ex.: OpenAI, Azure OpenAI).
- Coloque o valor em: `OPENAI_API_KEY=<sua_chave>`

## 2) Vetores / Banco (Qdrant / Postgres)

2.1 `VECTOR_DB`
- Valor padrão: `qdrant`

2.2 `QDRANT_URI` e `QDRANT_API_KEY`
- URI padrão local: `http://qdrant:6333`
- Qdrant padrão não exige API key; se habilitar auth, defina `QDRANT_API_KEY`.
- Teste de saúde: `curl -s http://127.0.0.1:6333/readyz`

2.3 Postgres: `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`, `DATABASE_URL`
- Sugestões:
  ```
  POSTGRES_USER=openwebui
  POSTGRES_PASSWORD=<defina>
  POSTGRES_DB=openwebui
  DATABASE_URL=postgresql://openwebui:<senha>@postgres:5432/openwebui
  ```
- Dica: o assistente pode gerar `DATABASE_URL` automaticamente se `POSTGRES_PASSWORD` estiver definido.

## 3) Integrações (opcionais)

3.1 Google Drive — `GOOGLE_SERVICE_ACCOUNT_JSON`
- Crie uma Service Account no Google Cloud e baixe o JSON.
- Converta para Base64 (sem quebras): `base64 -w0 service_account.json > /tmp/sa.b64`
- Cole o conteúdo no `.env`:
  ```
  GOOGLE_SERVICE_ACCOUNT_JSON=<conteudo_base64>
  ```
- Alternativa: monte o JSON como arquivo no container e referencie via caminho na app que for consumir.

3.2 Slack — `SLACK_BOT_TOKEN`, `SLACK_SIGNING_SECRET`
- Crie um Slack App e habilite permissões de bot.
- Obtenha o Bot Token (formato `xoxb-...`) e o Signing Secret no dashboard do app.
- Configure no `.env`:
  ```
  SLACK_BOT_TOKEN=xoxb-...
  SLACK_SIGNING_SECRET=...
  ```

3.3 Trello — `TRELLO_KEY`, `TRELLO_TOKEN`
- Acesse https://trello.com/app-key e gere sua Key e Token.
- Configure no `.env`:
  ```
  TRELLO_KEY=...
  TRELLO_TOKEN=...
  ```

## 4) DNS/HTTPS (opcional)

4.1 Cloudflare
- Defina o provider e token se for automatizar DNS/HTTPS:
  ```
  DNS_PROVIDER=cloudflare
  CF_API_TOKEN=<token>
  ```
- Nunca exponha tokens publicamente. Revogue quando não necessário.

## 5) Validação rápida

- Compose com overlay de segredos:
  ```bash
  cd /data/stack/ai_gateway
  docker compose \
    -f docker-compose.stack.yml \
    -f docker-compose.pins.yml \
    -f docker-compose.health.yml \
    -f docker-compose.env.yml up -d
  ```
- Health/Smoke/Audit + agregados:
  ```bash
  bash /data/stack/scripts/CHECKUP_ALL.sh
  ```
- Modelos (4000 e 4001):
  ```bash
  curl -s 127.0.0.1:4000/v1/models | jq -r '.data[]?.id' | head
  KEY=$(awk -F= '/^LITELLM_MASTER_KEY=/{print $2}' /data/stack/secrets/.env)
  curl -s -H "Authorization: Bearer $KEY" 127.0.0.1:4001/v1/models | jq -r '.data[]?.id' | head
  ```

## 6) Segurança e Rotação
- Guarde o `.env` com permissão 600.
- Rotacione `LITELLM_MASTER_KEY` se houver suspeita de vazamento.
- Troque senhas do OpenWebUI periodicamente; registre apenas a dica (`OPENWEBUI_ADMIN_HINT`).
- Remova chaves não utilizadas e limpe variáveis antigas.

## 7) Troubleshooting
- 401 no `:4001` → verifique `LITELLM_MASTER_KEY` e header `Authorization: Bearer <key>`.
- 500 intermitente (router) → aumentar `num_retries/timeout` no `ai_gateway/litellm.router.fb.yml`.
- Qdrant vazio → rode `python3 /data/stack/scripts/qdrant_seed_agents.py`.
- Provider na UI não lista híbridos → reabra Settings/Connections e valide `http://127.0.0.1:4001/v1` com o Bearer correto.
