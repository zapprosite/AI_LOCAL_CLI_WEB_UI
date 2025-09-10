# [Infra] Gateway LiteLLM + Observabilidade + Roteadores (Set/2025)

## Contexto
Padroniza gateway (**LiteLLM**) para modelos locais (Ollama) com fallback OpenAI, expõe **/metrics** (Prometheus), centraliza logs (Loki/Promtail) e estabelece aliases/roteadores por tipo de tarefa (**task:code**, **task:docs**).

## Objetivo
- Garantir estabilidade, healthcheck e restart automático.
- Roteamento por tarefa (code/docs) com fallback cloud quando necessário.
- Ativar observabilidade (métricas + logs) e bench mínimo.

## Mudanças
- : aliases locais e roteadores ; ; logs.
-  (ai_gateway): healthcheck, restart,  da OpenAI.
- Observabilidade: Prometheus (scrape ), Loki/Promtail para logs.
- Scripts utilitários: bench, coleta e geração de PR.

## Evidências

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

```

### Logs (docker logs --tail=200 litellm)
```
Error response from daemon: No such container: litellm
```

### Logfile (/data/stack/ai_gateway/logs/litellm.log tail)
```
N/A
```

### Bench (se disponível)
```
MODEL                STATUS     ms      SNIPPET
task:code            FAIL       7       
task:code            FAIL       7       
task:code            FAIL       7       
task:code            FAIL       7       
task:code            FAIL       6       
task:docs            FAIL       6       
task:docs            FAIL       6       
task:docs            FAIL       6       
task:docs            FAIL       6       
task:docs            FAIL       6       
openai/gpt-4o        FAIL       6       
openai/gpt-4o        FAIL       6       
openai/gpt-4o        FAIL       5       
openai/gpt-4o        FAIL       6       
openai/gpt-4o        FAIL       7       
openai/o3-pro        FAIL       6       
openai/o3-pro        FAIL       6       
openai/o3-pro        FAIL       7       
openai/o3-pro        FAIL       6       
openai/o3-pro        FAIL       6       
```

### Ambiente (container)
```
OPENAI_API_KEY=? (container)
```

## Riscos & Rollback
- Risco: consumo de RAM/VRAM sob carga; observar métricas.
- Rollback: reverter compose/YAML anteriores e .

## Checklist
- [ ] Healthcheck verde e restart automático.
- [ ] Métricas no Prometheus e logs no Loki/Grafana.
- [ ]  presente no container (não no repositório).
- [ ] Bench registrado (latência por tarefa/modelo).
- [ ] Backup de  e Qdrant agendados.

## Como testar
1. 
2. Pings code/docs conforme acima.
3. 
4. Grafana Explore: ver logs do job  e .
