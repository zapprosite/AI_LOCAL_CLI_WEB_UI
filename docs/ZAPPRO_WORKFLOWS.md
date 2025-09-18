# Workflows ZapPro (Construção Civil) — v2

Visão
- Fluxos práticos para orçamentos, laudos, memorial, compras e inspeções.
- Estruture prompts com contexto mínimo e peça sempre lista de próximos passos.

1) Orçamentos (CSC/insumos)
- Prompt base:
  > Contexto: Obra X, disciplina Y. Aponte insumos e CSCs típicos com quantitativos estimados. Gere planilha (CSV) com colunas: item, descrição, unidade, quantidade, custo_unitário, fonte.
- Modelo sugerido: `code.hybrid` (planilhas/macros) e validação com `docs.hybrid`.
- Dica: Importar planilhas existentes para comparação; peça “variações de mercado” e “risco de desabastecimento”.

2) Laudos e memorial descritivo
- Prompt base:
  > Considerando as normas NBR relevantes e o escopo anexo, produza um memorial descritivo por ambiente, com requisitos técnicos e checklist de conformidade.
- Modelo: `docs.hybrid` + Qdrant (normas internas). 
- Dica: Solicite saída em seções: escopo, materiais, execução, inspeção e normas.

3) Compras / Cotação
- Prompt base:
  > Elabore RFQ para os itens listados (CSV), incluindo especificações mínimas, prazos e garantia. Gere um e-mail de convite curto e uma planilha de comparação.
- Modelo: `code.hybrid` (planilha) e `docs.hybrid` (texto formal).
- Dica: Gerar 3 cotações simuladas para comparar e identificar outliers.

4) Cronograma executivo (alto nível)
- Prompt base:
  > Para obra X, gere WBS de alto nível (macroetapas) com durações aproximadas e dependências. Liste riscos e marcos de inspeção.
- Modelo: `docs.hybrid`.
- Dica: Exportar como CSV (tarefas, início_relativo, duração_dias, predecessor) e revisar no MS Project/Planner.

5) Inspeções de obra / Segurança
- Prompt base:
  > Crie checklist de inspeção para disciplina Y (normas A/B/C). Para cada item, inclua critério de aceite, evidência e nível de risco.
- Modelo: `docs.hybrid` + Qdrant (checklists internos).
- Dica: Gerar follow-up automático por e-mail (texto curto + anexos) para responsáveis.

Boas práticas (Refrimix)
- Sempre contextualize: obra, disciplina, normas aplicáveis, nível de detalhamento.
- Peça saídas acionáveis: lista de tarefas, riscos, dependências e próximos passos.
- Salve artefatos (planilhas, PDFs) em área padrão por projeto.
