# Segredos e Setup (v2)

Arquivos
- Catálogo (sem valores): `docs/SECRETS_RUNBOOK.md`
- Template público: `.env.example`
- Segredos reais (fora do Git): `/data/stack/secrets/.env`
- Assistente idempotente: `scripts/SETUP_ENV_SAFE.sh` (não sobrescreve, só preenche ausentes)
- Atalho Desktop: `Preencher-Segredos.desktop`

Como preencher (20s)
1) Duplo clique em “Preencher Segredos (Stack)” na Área de Trabalho.
2) Responder apenas o que o assistente pedir. O que já existir será mantido.
3) Se desejar, gere automaticamente `DATABASE_URL` quando perguntado.

Variáveis principais
- CORE: `LITELLM_MASTER_KEY`, `OPENAI_API_BASE` (default `http://litellm_fb:4001/v1`), `OPENAI_API_KEY` (opcional)
- VETORES/DB: `VECTOR_DB=qdrant`, `QDRANT_URI`, `POSTGRES_*`, `DATABASE_URL`
- Integrações: Google Drive (SA JSON Base64), Slack (bot/signing), Trello (key/token)
- DNS/HTTPS: `DNS_PROVIDER`, `CF_API_TOKEN`

Overlay env_file
- Compose overlay: `ai_gateway/docker-compose.env.yml` injeta `/data/stack/secrets/.env` em todos os serviços relevantes.

Comentários práticos (Refrimix)
- Gere `LITELLM_MASTER_KEY` forte e guarde seguro; é a chave de autenticação do roteador.
- `OPENAI_API_KEY` é opcional para operar localmente; mantenha off por padrão e habilite quando necessário.
- Para Google Drive, prefira arquivo montado + caminho; se usar Base64, documente origem e rotação.
