# Docs v2 — Refrimix Tecnologia + ZapPro Assistente (Construção Civil)

Este conjunto reúne documentação prática, orientada a operações e uso inteligente do stack para a Refrimix Tecnologia e para o ZapPro Assistente (foco: construção civil).

- Para começar: `README.md`
- Segredos e setup: `SECRETS_AND_SETUP.md`
- Interface Web (OpenWebUI): `OPENWEBUI.md`
- Modelos e roteamento (LiteLLM): `MODELS_AND_ROUTING.md`
- Vetores e Qdrant: `VECTORS_QDRANT.md`
- Operações e Health/Logs: `OPERATIONS.md`
- Workflows ZapPro (orçamento, laudos, compras etc.): `ZAPPRO_WORKFLOWS.md`
- Integração MCP (filesystem, memory, ripgrep, playwright): `MCP_TOOLS.md`

Comentários gerais
- Todos os exemplos usam caminhos reais sob `/data/stack` e overlays de compose.
- Mantemos valores sensíveis fora do Git (em `/data/stack/secrets/.env`); veja `SECRETS_AND_SETUP.md`.
- Logs são agregados automaticamente em `_logs` e rotacionados para `_archive`.
