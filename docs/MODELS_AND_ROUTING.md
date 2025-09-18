# Modelos e Roteamento (v2)

Camadas
- `:4000` (LiteLLM principal): aliases locais (fast/light/heavy) → Ollama.
- `:4001` (Router Fallback): híbridos (code/docs/search.hybrid), com retries/timeout ampliados.

Arquivos-chave
- `ai_gateway/config/litellm-config.yaml`: define aliases locais e híbridos.
- `ai_gateway/litellm.router.fb.yml`: roteador fallback; `num_retries: 3`, `timeout: 180`.
- `ai_gateway/docker-compose.openwebui.provider.yml`: OpenWebUI apontando para o roteador (interno) e aceitando conexão direta.

Good practices (Refrimix)
- Híbridos: aponte tarefas ao modelo correto:
  - `code.hybrid`: macros de planilhas, automações de orçamentos, parsing de notas técnicas.
  - `docs.hybrid`: revisão de contratos, memorial, normas e procedimentos.
  - `search.hybrid`: perguntas contextuais sobre documentos da obra.
- Ajuste de parâmetros: aumente `num_retries/timeout` em ambientes com latência de GPU/CPU.
- Autenticação: mantenha `LITELLM_MASTER_KEY` como única exigência para o `:4001` em rede local.
