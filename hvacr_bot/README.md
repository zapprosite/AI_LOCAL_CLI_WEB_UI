# HVAC-R WhatsApp Bot — README (Stack Local + Qdrant + LiteLLM)

> Este serviço é **opcional** e roda como **outro container** ao lado da sua stack.  
> Integra **WhatsApp Cloud API** → **RAG híbrido (Qdrant)** → **LLM via LiteLLM `:4001`** com **fallback mínimo**.

---

## 1) O que já temos no ambiente

- **liteLLM (:4000)** com aliases `fast|light|heavy` (OpenAI-compat).
- **liteLLM_FB (:4001)** com **routers e híbridos**:  
  `code.router`, `docs.router`, `search.router`, `openai.gpt5`,  
  `code.hybrid`, `docs.hybrid`, `search.hybrid`, e `*.remote`.
- **ollama** com modelos locais (ex.: `qwen2.5-coder:14b`, `qwen2.5:7b-instruct`, `llama3*`).
- **qdrant** (vetorial) em `http://qdrant:6333`.
- **openwebui** (cliente OpenAI-compat) em `http://localhost:3000`.
- **rede**: `ai_stack_net` (externa).
- **scripts**: `WAIT_HEALTH.sh`, `SMOKE_NOW.sh`, `FINAL_AUDIT.sh`.

> Pré-condição saudável: `FINAL_AUDIT.sh` deve mostrar `:4000=200` e `:4001=200` e listar `*.hybrid`.

---

## 2) O que este bot adiciona (sem colidir com nada)

- **Serviço `hvacr_bot` (porta 8088)**: FastAPI webhook de WhatsApp.
- **RAG híbrido** no **Qdrant** com **BGE-M3** (denso + sparse).
- **LLM** via **LiteLLM `:4001`** usando **`docs.hybrid`** como primário e **fallback** para `docs.remote` **somente se necessário** (baixa confiança ou erro).
- **Coleção padrão** no Qdrant: `hvacr_docs`.

---

## 3) Conexão com WhatsApp (Cloud API)

1. **Secrets (não versionar)** em `/data/stack/secrets/.env.whatsapp`:
WABA_VERIFY_TOKEN=troque-por-um-token-longo
WABA_TOKEN=EAAG... # token Bearer da Cloud API
WABA_PHONE_ID= # phone_number_id do número

markdown
￼Copiar código
2. **Webhook** do WhatsApp aponta para:
- **GET** `https://SEU_DOMINIO/webhook` (verificação com `WABA_VERIFY_TOKEN`).
- **POST** `https://SEU_DOMINIO/webhook` (mensagens).
> Em dev/local: publique `:8088` via seu proxy/ túnel e mapeie para `/webhook`.

---

## 4) Variáveis do bot (já previstas no overlay)

- **LLM**: `LLM_API_BASE=http://litellm_fb:4000`, `LLM_CHAT_PATH=/v1/chat/completions`, `LLM_API_KEY=${LITELLM_MASTER_KEY}`, `LLM_MODEL_DOCS=docs.hybrid`, `LLM_MODEL_CODE=code.hybrid`.
- **Qdrant**: `QDRANT_URL=http://qdrant:6333`, `QDRANT_COLLECTION=hvacr_docs`.
- **WhatsApp**: `WABA_VERIFY_TOKEN`, `WABA_TOKEN`, `WABA_PHONE_ID`.

---

## 5) Como subir (build + run)

1) **Carregar secrets** no shell (sem gravar em `.env`):
set -a; . /data/stack/secrets/.env.whatsapp; set +a

markdown
￼Copiar código

2) **Subir o serviço** (overlay `docker-compose.hvacr.yml`):
cd /data/stack/ai_gateway
docker compose -f docker-compose.stack.yml -f docker-compose.pins.yml -f docker-compose.health.yml -f docker-compose.hvacr.yml build hvacr_bot
docker compose -f docker-compose.stack.yml -f docker-compose.pins.yml -f docker-compose.health.yml -f docker-compose.hvacr.yml up -d hvacr_bot

markdown
￼Copiar código

3) **Health**:
curl -sS http://127.0.0.1:8088/health

yaml
￼Copiar código

---

## 6) Ingest de documentos HVAC-R (VRV/VRF)

- Coloque seus PDFs em **`/data/hvacr/pdfs`** (organize por marca/modelo/revisão se quiser).
- Rode o ingestor para criar/atualizar a coleção `hvacr_docs`:
docker compose -f /data/stack/ai_gateway/docker-compose.stack.yml
-f /data/stack/ai_gateway/docker-compose.pins.yml
-f /data/stack/ai_gateway/docker-compose.health.yml
-f /data/stack/ai_gateway/docker-compose.hvacr.yml
exec hvacr_bot python3 ingest/ingest_hvacr.py

yaml
￼Copiar código

> Chunk ~1200 tokens, overlap ~150; payload inclui `doc_src` e `text`.

---

## 7) Fluxo de resposta (resumo)

1. Recebe texto do WhatsApp → extrai pergunta.  
2. **RAG híbrido** (denso + sparse) no Qdrant → top-k trechos.  
3. **Heurística de confiança** (score mínimo).  
   - Se **ok** → chama **`docs.hybrid`** no `:4001`.  
   - Se **baixo/erro** → tenta `docs.hybrid` de novo; se vazio, **força `docs.remote`** (fallback mínimo).
4. Responde no WhatsApp (mensagem de texto até 4096 chars).

---

## 8) Testes

- **Modelos disponíveis (`:4001`)**:
AUTH=$(grep -m1 '^LITELLM_MASTER_KEY=' /data/stack/ai_gateway/.env|cut -d= -f2-)
curl -sS -H "Authorization: Bearer $AUTH" http://127.0.0.1:4001/v1/models | jq -r '.data[].id' | sort

bash
￼Copiar código

- **Simular POST do WhatsApp (local)**:
curl -sS -X POST http://127.0.0.1:8088/webhook
-H 'Content-Type: application/json'
-d '{"entry":[{"changes":[{"value":{"contacts":[{"wa_id":"5599999999999"}],"messages":[{"from":"5599999999999","type":"text","text":{"body":"Procedimento de startup VRV com Service Checker?"}}],"metadata":{"phone_number_id":"'$WABA_PHONE_ID'"}}]}]}]}'

yaml
￼Copiar código

---

## 9) Observabilidade & troubleshooting

- Logs do bot:
docker logs -f $(docker ps -q -f name=ai_gateway-hvacr_bot-1)

diff
￼Copiar código
- Qdrant pronto:
curl -sS http://127.0.0.1:6333/readyz

bash
￼Copiar código
- Fallback forçado (desligar local):
docker stop ai_gateway-ollama-1 && sleep 3

faça uma pergunta e veja provider openai/* no retorno
docker start ai_gateway-ollama-1 && sleep 5

markdown
￼Copiar código

---

## 10) Segurança e PR

- **Secrets** ficam em `/data/stack/secrets/.env.whatsapp` (NÃO comitar).
- `.gitignore` do repo já ignora `secrets/`, `_archive/`, `openwebui/`, `qdrant/`, `ollama/`.
- Para PR: subir **somente** `docker-compose.hvacr.yml` e o diretório `hvacr_bot/` (código do serviço).

