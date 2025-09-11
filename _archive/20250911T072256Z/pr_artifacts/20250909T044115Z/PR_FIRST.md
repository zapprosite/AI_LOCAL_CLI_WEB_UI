# [Infra] Gateway LiteLLM + Observabilidade + Roteadores (Set/2025)

## Contexto
Padroniza gateway (**LiteLLM**) p/ modelos locais (Ollama) com fallback OpenAI; expõe **/metrics** (Prometheus); logs em Loki/Promtail; aliases/roteadores (**task:code**, **task:docs**).

## Objetivo
- Estabilidade, healthcheck e restart automático.
- Roteamento por tarefa (code/docs) com fallback cloud quando necessário.
- Observabilidade (métricas + logs) e bench mínimo.

## Mudanças
- `litellm.yaml`: aliases locais + roteadores `simple_fallback`; `callbacks: ["prometheus"]`; logs.
- `docker-compose.yml` (ai_gateway): healthcheck, restart, `env_file` da OpenAI.
- Observabilidade: Prometheus (scrape `litellm:4000/metrics`), Loki/Promtail.
- Scripts: bench, coleta e geração de PR.

## Evidências

### docker ps (resumo)
```
NAMES        STATUS          PORTS
ollama       Up 4 hours      0.0.0.0:11434->11434/tcp, [::]:11434->11434/tcp
qdrant       Up 18 hours     0.0.0.0:6333->6333/tcp, [::]:6333->6333/tcp, 6334/tcp
```

### /v1/models
```json
```

### Ping chat (task:code)
```json
```

### Ping chat (task:docs)
```json
```

### /metrics (head)
```
curl: (7) Failed to connect to 127.0.0.1 port 4000 after 0 ms: Couldn't connect to server
```

### Logs (docker logs --tail=200 litellm)
```
Error response from daemon: No such container: litellm
```

### Logfile (/data/stack/ai_gateway/logs/litellm.log tail)
```
no litellm.log
```

### Bench
```
MODEL                STATUS     ms      SNIPPET
task:code            FAIL       6       
task:code            FAIL       6       
task:code            FAIL       6       
task:code            FAIL       7       
task:code            FAIL       6       
task:docs            FAIL       7       
task:docs            FAIL       6       
task:docs            FAIL       6       
task:docs            FAIL       5       
task:docs            FAIL       6       
openai/gpt-4o        FAIL       7       
openai/gpt-4o        FAIL       7       
openai/gpt-4o        FAIL       7       
openai/gpt-4o        FAIL       6       
openai/gpt-4o        FAIL       6       
openai/o3-pro        FAIL       6       
openai/o3-pro        FAIL       7       
openai/o3-pro        FAIL       7       
openai/o3-pro        FAIL       6       
openai/o3-pro        FAIL       8       
```

### Ambiente (container)
```
OPENAI_API_KEY=? (container)
```

## Riscos & Rollback
- RAM/VRAM sob carga; observar métricas. Rollback: reverter compose/YAML e `docker compose up -d`.

## Checklist
- [ ] Healthcheck verde + restart automático
- [ ] Métricas no Prometheus e logs no Loki/Grafana
- [ ] `OPENAI_API_KEY` presente no container (não no repo)
- [ ] Bench registrado (latência por tarefa/modelo)
- [ ] Backup de `litellm.yaml` e Qdrant agendados

## Como testar
1) `curl -s http://localhost:4000/v1/models | jq .`
2) Pings code/docs conforme acima
3) `curl -s http://localhost:4000/metrics | head`
4) Grafana Explore (Loki): ver logs do job `litellm_file` e `docker`
