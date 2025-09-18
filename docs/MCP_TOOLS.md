# Integração MCP (Model Context Protocol)

O que é
- Padrão para conectar o assistente a ferramentas via “servidores MCP”.
- Já disponível: memory, filesystem, ripgrep, playwright.

Servidores disponíveis
- Memory: grafo de conhecimento (entidades, relações, observações).
- Filesystem: leitura/escrita de arquivos e diretórios dentro de whitelists.
- Ripgrep: buscas rápidas por conteúdo/caminhos.
- Playwright: automação de browser (navegar, preencher, clicar, screenshot).

Casos de uso (ZapPro)
- Filesystem + Ripgrep: localizar contratos, normas, escopos e planilhas por obra.
- Memory: registrar decisões e vínculos (obra → disciplina → tarefas → responsáveis).
- Playwright: validação E2E da UI (evidência por screenshot anexada a PRs).

Como usar (padrões)
- Executar buscas:
  > Ripgrep: procurar “NBR 5410” em docs de elétrica.
- Ler/editar arquivos:
  > Filesystem: abrir `docs/v2/ZAPPRO_WORKFLOWS.md` e salvar alterações.
- Registrar conhecimento:
  > Memory: adicionar entidade “Obra X”, relacionar “Disciplina elétrica”, observações “Normas aplicáveis: NBR 5410…”.
- Testar UI:
  > Playwright: abrir OpenWebUI, logar, confirmar modelos `*.hybrid` e tirar screenshot.

Notas
- Padrões de segurança limitam o acesso a diretórios: ajuste whitelists conforme necessidade.
- Sempre gere evidências (logs/screenshots) para PRs e auditorias.
