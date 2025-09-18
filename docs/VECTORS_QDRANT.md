# Vetores e Qdrant

Objetivo
- Indexar conhecimento de obra (normas, memorial, escopo, contratos, notas técnicas) para respostas contextuais.

Serviço
- Porta: `6333` (dashboard embutido: `/dashboard`).
- Seeds: `scripts/qdrant_seed_agents.py` cria coleções `agents_kb` e `docs_kb` (idempotente).

Como usar (ZapPro)
- Separe coleções por projeto/obra e por tipo de conteúdo (normas, contratos, escopo, diário de obra).
- Carregue documentos (PDF, DOCX, TXT) com metadados (obra, autor, data, disciplina).
- Use prompts com “contexto preferencial”: “considere primeiro documentos da obra X e normas NBR-Y”.

Operações
- Health check via dashboard: http://localhost:6333/dashboard
- Seeds: `python3 /data/stack/scripts/qdrant_seed_agents.py`
- Backup/restore: snapshot de `/data/qdrant` (considere janelas de manutenção).

Boas práticas
- Curadoria de fontes: mantenha um padrão de nomenclatura e metadados para busca eficiente.
- Clean-up: rotacione coleções antigas e compacte índice após grandes remoções.
