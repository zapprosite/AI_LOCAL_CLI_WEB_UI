# OpenWebUI (v2)

Objetivo
- UI para conversa, testes rápidos e fluxos de trabalho (com compatibilidade OpenAI e conexões diretas).

Configuração
- Overlay: `docker-compose.openwebui.provider.yml` já aponta para `http://litellm_fb:4000/v1` dentro da rede do compose.
- Conexão Direta: em Settings → Connections, adicione `http://127.0.0.1:4001/v1` com Bearer `${LITELLM_MASTER_KEY}` para listar modelos híbridos.

Login e segurança
- Primeiro acesso pede criação/uso de admin.
- Rotacione a senha após testes (não registre no Git). Dica opcional: `OPENWEBUI_ADMIN_HINT` em `/data/stack/secrets/.env`.

Como usar (ZapPro)
- “Model selector” deve listar `code.hybrid`, `docs.hybrid` e `search.hybrid` (rota pelo `:4001`).
- Use “Direct” para filtrar modelos configurados via conexão direta.
- Mantenha prompts curtos com contexto de obra e peça checklists (por exemplo: inspeção de segurança, orçamento por CSC, memorial descritivo por ambiente).

Dicas inteligentes
- Crie “system prompts” específicos por função: Orçamentista, Engenheiro, Compras, Qualidade.
- Adote padrões de resposta: resumo executivo (3–5 bullets), riscos/pendências, próximos passos.
- Para uploads, utilize o armazenamento do OpenWebUI e referencie arquivos no prompt.
