# Login por Telefone + JWT para OpenWebUI (Plano)

Objetivo
- Permitir autenticação por número de celular (OTP) e emissão de JWT, antes de acessar o OpenWebUI.

Arquitetura (Fase 1 — Gateway JWT)
- Serviço `auth_sms` (FastAPI) em `:8081`:
  - POST /otp/request { phone } → gera/enviar código (demo: devolve no JSON)
  - POST /otp/verify { phone, code } → valida e emite JWT (HS256), setando cookie `x-auth-phone`
  - GET /signin?token=... → valida JWT e redireciona ao OpenWebUI
- OpenWebUI permanece inalterado (login próprio opcional). Nesta fase, o JWT serve como *gating* simples.

Arquivos
- App: `apps/auth-sms/` (Dockerfile, app.py)
- Compose overlay: `ai_gateway/docker-compose.auth.sms.yml`
- Segredos: defina `OPENWEBUI_JWT_SECRET` em `/data/stack/secrets/.env`

Subida
```bash
cd /data/stack/ai_gateway
# inclui overlay do auth_sms
docker compose \
  -f docker-compose.stack.yml \
  -f docker-compose.pins.yml \
  -f docker-compose.health.yml \
  -f docker-compose.env.yml \
  -f docker-compose.auth.sms.yml up -d --build
```

Uso (demo local)
```bash
# 1) Solicitar OTP
curl -s -X POST -d 'phone=+55XXXXXXXXXXX' http://127.0.0.1:8081/otp/request | jq
# 2) Verificar OTP e obter token
curl -s -X POST http://127.0.0.1:8081/otp/verify \
  -H 'Content-Type: application/json' \
  -d '{"phone":"+55XXXXXXXXXXX","code":"<code>"}' | jq
# 3) Abrir no navegador
xdg-open 'http://127.0.0.1:8081/signin?token=<TOKEN_JWT>'
```

Integração e Endurecimento (Fase 2 — Integração profunda)
- Proxy reverso (nginx/traefik) exigindo JWT válido em `x-auth-phone`/Authorization antes de encaminhar para o OpenWebUI.
- Integração com o cookie de sessão do OpenWebUI (se exposto):
  - Alinhar o `JWT_SECRET` com o segredo do OpenWebUI (se suportar env para JWT).
  - Alternativa: criar/atualizar usuário no SQLite do OpenWebUI e iniciar sessão programaticamente.
- Provider real (Twilio/WhatsApp/SMS) no `auth_sms` (substituir demo OTP por envio real de código).

Segurança
- Usar `HTTPS` no proxy real.
- Mover `JWT_SECRET` para `/data/stack/secrets/.env` como `OPENWEBUI_JWT_SECRET`.
- Configurar validade curta (ex.: 15–30 min) e refresh conforme necessidade.

Notas
- Esta solução é incremental. A fase 1 entrega o gating por JWT; a fase 2 integra sessão/cookie do OpenWebUI.
- Caso o OpenWebUI adote OIDC/JWT nativo, podemos migrar para provedor OIDC com login por SMS.
