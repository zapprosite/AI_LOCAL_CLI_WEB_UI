# Visão Geral (v2)

Objetivo
- Operar e evoluir a stack de IA local da Refrimix, oferecendo ao ZapPro Assistente (construção civil) modelos híbridos e ferramentas para apoiar orçamentos, laudos, memorial descritivo, compras, cronograma e inspeções de obra.

O que temos
- Orquestração Docker (serviços: Ollama, LiteLLM `:4000`, Router Fallback `:4001`, OpenWebUI, Qdrant).
- Modelos híbridos expostos no `:4001` (code/docs/search.hybrid) e aliases locais no `:4000` (fast/light/heavy).
- UI OpenWebUI compatível com API OpenAI + conexões diretas.
- Armazenamento vetorial Qdrant (coleções seeds `agents_kb` e `docs_kb`).
- Governança de segredos (assistente idempotente + overlay env_file).
- Checkups automatizados (WAIT/SMOKE/AUDIT, DATA_STANDARDIZE, listas de modelos, seeds) com logcodex consolidado.
- Integração MCP para automações (filesystem, ripgrep, memory, playwright).

Como usar
1) Preencha segredos: rode o atalho Desktop “Preencher Segredos (Stack)” ou `scripts/SETUP_ENV_SAFE.sh`.
2) Suba a stack (sempre com overlay `docker-compose.env.yml`).
3) Garanta saúde e evidências: `scripts/CHECKUP_ALL.sh` (gera `logcodex.md`, rota e arquiva logs; copia para Desktop).
4) Use a UI (OpenWebUI porta 3000) com provedor roteado para `:4001/v1`.
5) Para fluxos de obra, siga `ZAPPRO_WORKFLOWS.md`.

Notas Refrimix (inteligência de uso)
- Em obras, priorize respostas curtas e objetivas, com checklists e passos de ação.
- Separe contexto por fontes: “normas técnicas”, “contratos”, “escopo”, “orçamentos”. Use Qdrant para recuperação.
- Para compras, integre planilhas e catálogos (importação de CSV/Excel) e gere comparativos.
- Para segurança do trabalho e qualidade, crie prompts com restrições normativas e checklists de inspeção.

Próximos passos
- Ajustar timeouts/retries conforme latência da máquina e dos modelos.
- Adicionar CI E2E (Playwright) com screenshots de modelos híbridos por PR.
- Conectar dados reais (docs técnicos e contratos) ao Qdrant e organizar coleções por projeto/obra.
