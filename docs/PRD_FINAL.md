# PRD_FINAL

> **Status**: synchronized  
> **Host**: zappro  
> **Last Audited**: 2025-09-16T05:44:26-03:00  
> **Stack Summary**:  
> ```
> (audit fail)
> ```

## Overview
Short purpose of this document in the AI local stack (GPU + LiteLLM Router + Ollama + OpenWebUI + Qdrant). Keep it concise and actionable.

## Architecture Context
- Router (ports 4000/4001), hybrids: code/docs/search → fallback openai/gpt-5  
- Local models via Ollama (qwen2.5-coder:14b etc.)
- OpenWebUI as OpenAI-compatible client  
- Vector store: Qdrant

## Operations (Terminal-only)
- Health: `ai_gateway/WAIT_HEALTH.sh`  
- Smoke: `ai_gateway/SMOKE_NOW.sh`  
- Final audit: `ai_gateway/FINAL_AUDIT.sh`

## How to Use
Step-by-step relevant to this document. Example requests, env vars, compose overlays.

## Troubleshooting
Common pitfalls + quick commands.

## Legacy Notes
(Original content preserved below)

----
## Legacy Notes (raw)

# PRD — Infra IA Local (versão definitiva)  
*Última revisão : 2025-09-09*

---

## 1. Objetivo
Padronizar a stack de inferência local (GPU RTX 4090) para:
- **CLI** de código (modelos locais)  
- **WebUI** de chat/docs  
- **Fallback seguro** → `o3-pro` *somente* quando `FINAL_CHECK=1`  
- **Memória vetorial opcional** (Qdrant)  
- **IaC** reprodutível via Pulumi

---

## 2. Abrangência
Cobre **apenas** `/data/stack` (produção).  
Labs e templates ⇒ `/data/stack/_labs/`.  
Arquivos antigos ⇒ `/data/stack/ai_gateway/_old/`.

---

## 3. Estrutura de pastas (padrão ouro)
/data/stack/
├── ai_gateway/
│ ├── docker-compose.stack.yml
│ ├── .env
│ ├── .env.example
│ ├── CHECK_PORTS.sh
│ ├── UP.sh
│ ├── STATUS.sh
│ ├── config/
│ │ └── litellm-config.yaml
│ ├── logs/
│ └── _old/
├── pulumi_ai_gateway/
│ ├── Pulumi.yaml
│ └── STACK.dev.yaml
├── docs/
│ ├── README.md
│ └── PRD_FINAL.md
└── _labs/

yaml
￼Copiar código

---

## 4. Serviços e portas
| Serviço | Porta | Health-check | Volume |
|---------|-------|--------------|--------|
| Ollama | 11434 | `GET /api/tags` | `/data/ollama → /root/.ollama` |
| LiteLLM | 4000 | `GET /v1/models` | `config/litellm-config.yaml` |
| Open WebUI | 3000 | HTTP 200 `/` | `/data/openwebui` |
| Qdrant* | 6333 | `GET /readyz` | `/data/qdrant/data` |
\* opcional

---

## 5. Arquivos obrigatórios
| Arquivo | Responsabilidade |
|---------|------------------|
| `docker-compose.stack.yml` | Compose único |
| `.env` / `.env.example` | Variáveis |
| `config/litellm-config.yaml` | FAST/LIGHT/HEAVY + fallback |
| `CHECK_PORTS.sh` | Abort se portas ocupadas |
| `UP.sh` | Check → up → status |
| `STATUS.sh` | `compose ps` + curls |
| `Pulumi.yaml` + `STACK.dev.yaml` | IaC |
| `README.md` | Instruções dev |
| `PRD_FINAL.md` | Contrato |

---

## 6. Fluxos
### CLI local-first
`ask-code.sh "Refatore script"`  
### Fallback
`FINAL_CHECK=1 ask-code.sh "..."`  
### Ciclo
cd /data/stack/ai_gateway
./UP.sh
./STATUS.sh
docker compose down -v

yaml
￼Copiar código

---

## 7. Princípios
1. **Um Compose, um config, três scripts**  
2. Arquivos via `sudo tee <<'EOF'`  
3. Idempotência total  
4. Fallback só com `FINAL_CHECK=1`  
5. Segredos só em `.env`  
6. Volumes em `/data/...`  
7. Pulumi garante portabilidade  
8. Logs em `ai_gateway/logs/`

---

## 8. Contribuição
- Branch `feat/stack-root/<escopo>`  
- Commits `feat|fix|ci|chore`  
- PR inclui objetivo, mudanças, rollback, riscos, links  
- Alterações neste PRD requerem atualizar este arquivo

---

## 9. Histórico
Arquivos movidos para `_old/` devem ser citados no PR.  
Rollback = mover de volta + `./UP.sh`.

