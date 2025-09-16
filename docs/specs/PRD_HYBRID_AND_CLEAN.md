# docs/PRD_HYBRID_AND_CLEAN.md

## 1. Contexto
Expor modelos **locais** (Ollama) e **híbridos** (via router LiteLLM fallback em :4001) no **OpenWebUI**, e padronizar a estrutura **/data** para operação idempotente.

## 2. Escopo
- Configurar aliases `fast|light|heavy` no LiteLLM (:4000).
- Expor `code.hybrid|docs.hybrid|search.hybrid` via router `litellm_fb:4001`.
- OpenWebUI usando provider OpenAI apontando para `litellm_fb:4001/v1`.
- Script `scripts/DATA_STANDARDIZE.sh` para padronizar /data.

## 3. Não-escopo
- Troca de modelos base/weights.
- Alteração de rede/hostnames externos.
- Migração destrutiva de dados.

## 4. Critérios de Aceite
- `GET :4000/v1/models` lista **fast, light, heavy, code.hybrid, docs.hybrid, search.hybrid**.
- `GET :4001/v1/models` responde 200 com Authorization Bearer (master key).
- OpenWebUI carrega com provider remoto e **exibe os híbridos** na lista.
- `scripts/DATA_STANDARDIZE.sh` roda em `MODE=dry` e `MODE=apply` sem erros.
- `WAIT_HEALTH.sh`, `SMOKE_NOW.sh`, `FINAL_AUDIT.sh` passam; logs impressos no terminal.

## 5. Teste / Operação
```bash
# Compose config
cd ai_gateway
docker compose -f docker-compose.stack.yml -f docker-compose.pins.yml -f docker-compose.health.yml config >/dev/null && echo "compose config OK"

# Bring-up
./WAIT_HEALTH.sh | tee /data/stack/_logs/wait.txt
./SMOKE_NOW.sh   | tee /data/stack/_logs/smoke.txt
./FINAL_AUDIT.sh | tee /data/stack/_logs/audit.txt

# Data standardization
MODE=dry   scripts/DATA_STANDARDIZE.sh | tee /data/stack/_logs/data_std_dry.txt
MODE=apply scripts/DATA_STANDARDIZE.sh | tee /data/stack/_logs/data_std_apply.txt
```

