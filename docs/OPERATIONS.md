# Operações, Health e Logs

Checkups
- Script principal: `scripts/CHECKUP_ALL.sh`
  - WAIT/SMOKE/AUDIT
  - DATA_STANDARDIZE (dry/apply)
  - Lista modelos (4000/4001) com backoff no `:4001`
  - Seeds Qdrant
  - Gera `logcodex_*.md`, copia para Desktop e rotaciona `_logs/*.txt` + `logcodex_*.md` para `_archive`.

Cron
- Instalador: `scripts/install_cron_checkup.sh` (hora em hora)
- Log do cron: `_logs/checkup_cron.log`

Logs e evidências
- `_logs/` mantém últimos artefatos (health, smoke, audit, models, seeds, screenshots)
- `_archive/<ts>/logs` e `_archive/<ts>/logcodex` guardam históricos

Desempenho/Resiliência
- Router fallback com `num_retries: 3` e `timeout: 180`.
- Ajuste se notar 500/timeout intermitentes em `code.hybrid.fb`.

Procedimentos
- Subida: compose com overlays `health`, `env`, e quando necessário `litellm.fb` e `openwebui.provider`.
- Sanidade final:
  ```bash
  curl -s 127.0.0.1:4000/v1/models | jq -r '.data[]?.id' | head
  KEY=$(awk -F= '/^LITELLM_MASTER_KEY=/{print $2}' /data/stack/secrets/.env || awk -F= '/^LITELLM_MASTER_KEY=/{print $2}' /data/stack/ai_gateway/.env)
  curl -s -H "Authorization: Bearer $KEY" 127.0.0.1:4001/v1/models | jq -r '.data[]?.id' | head
  ```
