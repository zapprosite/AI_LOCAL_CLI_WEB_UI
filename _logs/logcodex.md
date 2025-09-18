# logcodex.md

## Source: /data/stack/docs/specs/PRD_MAP_TEST_DEBUG.md

# docs/specs/PRD_MAP_TEST_DEBUG.md

## 1. Contexto
Projeto `/data/stack` com serviços:
- **ollama** (modelos locais)
- **litellm** (:4000 aliases fast/light/heavy)
- **litellm_fb** (:4001 router fallback/híbridos)
- **openwebui** (interface compatível OpenAI)
- **qdrant** (vetorial)
- **console qdrant** (admin web, novo)

Problemas:
- OpenWebUI não exibe modelos híbridos.
- /v1/models em :4001 retorna erro 400/401.
- Estrutura /data inconsistente.
- Qdrant sem interface nem coleções seeds.

---

## 2. Escopo
- Mapear serviços e validar health.
- Corrigir `api_base` dos híbridos → litellm_fb.
- Corrigir provider OpenWebUI → router fallback.
- Expor console Qdrant (web admin) em 6335.
- Criar seed script p/ coleções de agentes.
- Padronizar `/data` com script DATA_STANDARDIZE.

---

## 3. Critérios de Aceite
- `GET :4000/v1/models` → fast|light|heavy.
- `GET :4001/v1/models` → code.hybrid|docs.hybrid|search.hybrid.
- OpenWebUI lista híbridos.
- Qdrant acessível em http://localhost:6333/dashboard e console em 6335.
- Coleções seeds criadas: `agents_kb`, `docs_kb`.
- `DATA_STANDARDIZE.sh` roda em dry/apply sem erros.
- WAIT_HEALTH.sh, SMOKE_NOW.sh, FINAL_AUDIT.sh passam.

---

## 4. Testes
```bash
cd /data/stack/ai_gateway

docker compose -f docker-compose.stack.yml -f docker-compose.pins.yml -f docker-compose.health.yml -f docker-compose.openwebui.provider.yml -f docker-compose.qdrant.console.yml config >/dev/null && echo "compose config OK"

./WAIT_HEALTH.sh | tee /data/stack/_logs/wait.txt
./SMOKE_NOW.sh   | tee /data/stack/_logs/smoke.txt
./FINAL_AUDIT.sh | tee /data/stack/_logs/audit.txt

MODE=dry   /data/stack/scripts/DATA_STANDARDIZE.sh | tee /data/stack/_logs/data_std_dry.txt
MODE=apply /data/stack/scripts/DATA_STANDARDIZE.sh | tee /data/stack/_logs/data_std_apply.txt

python3 /data/stack/scripts/qdrant_seed_agents.py
```

## 5. Rollback
```bash
cd /data/stack

git checkout -B rescue/<ts>

git revert -n <commits>

docker compose -f ai_gateway/docker-compose.stack.yml down; # subir baseline
```

## 6. Observabilidade
- Logs stdout/stderr salvos em `_logs/`.
- Secrets em `.env` + `/data/stack/secrets/.env.openai`.

---

## 🔧 Patches Codex CLI

### 1) litellm-config.yaml
```bash
codex --diff /data/stack/ai_gateway/config/litellm-config.yaml <<'AI_PATCH'
# /data/stack/ai_gateway/config/litellm-config.yaml
...
  # ==== HÍBRIDOS ====
  - model_name: code.hybrid
    litellm_params:
      model: "openai.gpt5"
      api_base: "http://litellm_fb:4000"
      api_key: "os.environ/LITELLM_MASTER_KEY"

  - model_name: docs.hybrid
    litellm_params:
      model: "openai.gpt5"
      api_base: "http://litellm_fb:4000"
      api_key: "os.environ/LITELLM_MASTER_KEY"

  - model_name: search.hybrid
    litellm_params:
      model: "openai.gpt5"
      api_base: "http://litellm_fb:4000"
      api_key: "os.environ/LITELLM_MASTER_KEY"
AI_PATCH
codex --apply | tee /data/stack/_logs/codex_apply_litellm_hybrids.txt
```

### 2) docker-compose.openwebui.provider.yml
```bash
codex --diff /data/stack/ai_gateway/docker-compose.openwebui.provider.yml <<'AI_PATCH'
services:
  openwebui:
    environment:
      - OPENAI_API_BASE=http://litellm_fb:4000/v1
      - OPENAI_API_KEY=${LITELLM_MASTER_KEY}
      - WEBUI_PROVIDER=OpenAI
    depends_on:
      - litellm_fb
AI_PATCH
codex --apply | tee /data/stack/_logs/codex_apply_openwebui_provider_fix.txt
```

### 3) docker-compose.qdrant.console.yml
```bash
codex --diff /data/stack/ai_gateway/docker-compose.qdrant.console.yml <<'AI_PATCH'
# /data/stack/ai_gateway/docker-compose.qdrant.console.yml
services:
  qdrant_console:
    image: qdrant/qdrant-console:latest
    ports:
      - "6335:80"
    depends_on:
      - qdrant
    networks: [ai_stack_net]

networks:
  ai_stack_net:
    external: true
AI_PATCH
codex --apply | tee /data/stack/_logs/codex_apply_qdrant_console.txt
```

### 4) scripts/qdrant_seed_agents.py
```bash
codex --diff /data/stack/scripts/qdrant_seed_agents.py <<'AI_PATCH'
# /data/stack/scripts/qdrant_seed_agents.py
#!/usr/bin/env python3
import requests, sys

QDRANT="http://localhost:6333"

collections = ["agents_kb", "docs_kb"]

for c in collections:
    r = requests.put(f"{QDRANT}/collections/{c}", json={
        "vectors": {"size": 1536, "distance": "Cosine"}
    })
    print(f"Seeded {c}: {r.status_code} {r.text}")
AI_PATCH
codex --apply | tee /data/stack/_logs/codex_apply_qdrant_seed.txt
chmod +x /data/stack/scripts/qdrant_seed_agents.py
```

### 🚀 Instruct
- Rodar os blocos Codex acima (PRD + 3 patches + seed script).
- Fazer commit/push na branch `feat/map-test-debug`:

```bash
cd /data/stack
git checkout -B feat/map-test-debug
git add docs/specs/PRD_MAP_TEST_DEBUG.md ai_gateway/docker-compose.qdrant.console.yml ai_gateway/docker-compose.openwebui.provider.yml ai_gateway/config/litellm-config.yaml scripts/qdrant_seed_agents.py
git commit -m "feat(stack): mapping, test & debug with Qdrant console + seeds"
git push -u origin feat/map-test-debug
codex pr create -t "Map, Test & Debug Stack (/data)" -F docs/specs/PRD_MAP_TEST_DEBUG.md
```

- Subir stack com overlay novo + rodar health/audit.
- Confirmar no OpenWebUI que `*.hybrid` aparecem.
- Acessar Qdrant Console em http://localhost:6335 e verificar coleções seeds.

---

## Source: /data/stack/scripts/qdrant_seed_agents.py

#!/usr/bin/env python3
import requests, sys

QDRANT = "http://localhost:6333"

collections = ["agents_kb", "docs_kb"]

for c in collections:
    r = requests.put(f"{QDRANT}/collections/{c}", json={
        "vectors": {"size": 1536, "distance": "Cosine"}
    })
    print(f"Seeded {c}: {r.status_code} {r.text}")

---

## Source: /data/stack/_logs/wait.txt

PORT=4000 TRY=1 HTTP=200
PORT=4001 TRY=1 HTTP=200

---

## Source: /data/stack/_logs/smoke.txt

>>> MODELS :4000 / :4001
fast
heavy
light
code.hybrid
docs.hybrid
search.hybrid
>>> code.router
null
null
>>> code.hybrid (local)
ollama/qwen2.5-coder:14b
4

---

## Source: /data/stack/_logs/audit.txt

SUMMARY :4000=200 :4001=200 MODELS4000=[fast,light,heavy] MODELS4001=[code.hybrid,docs.hybrid,search.hybrid] fast=200 code.router=400 code.hybrid.local=200 code.hybrid.fb=500 openwebui="ai_gateway-openwebui-1	0.0.0.0:3000->8080/tcp, [::]:3000->8080/tcp" qdrant=200

---

## Source: /data/stack/_logs/models_4000.txt


---

## Source: /data/stack/_logs/models_4001.txt

code.hybrid
docs.hybrid
search.hybrid

---

## Source: /data/stack/_logs/qdrant_seed.txt

Seeded agents_kb: 200 {"result":true,"status":"ok","time":0.100060871}
Seeded docs_kb: 200 {"result":true,"status":"ok","time":0.098197674}

---

## Source: /data/stack/_logs/ollama_tail.txt

[GIN] 2025/09/18 - 17:58:28 | 200 |  5.799336028s |      172.22.0.5 | POST     "/api/generate"
[GIN] 2025/09/18 - 17:58:30 | 200 |  1.690133526s |      172.22.0.2 | POST     "/api/generate"
[GIN] 2025/09/18 - 17:58:32 | 200 |  1.672360927s |      172.22.0.5 | POST     "/api/generate"

---

## Source: /data/stack/_logs/nvidia_smi.txt

Thu Sep 18 14:59:23 2025       
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 575.64.03              Driver Version: 575.64.03      CUDA Version: 12.9     |
|-----------------------------------------+------------------------+----------------------+
| GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
| Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
|                                         |                        |               MIG M. |
|=========================================+========================+======================|
|   0  NVIDIA GeForce RTX 4090        On  |   00000000:01:00.0  On |                  Off |
|  0%   29C    P8             27W /  480W |    1359MiB /  24564MiB |      0%      Default |
|                                         |                        |                  N/A |
+-----------------------------------------+------------------------+----------------------+
                                                                                         
+-----------------------------------------------------------------------------------------+
| Processes:                                                                              |
|  GPU   GI   CI              PID   Type   Process name                        GPU Memory |
|        ID   ID                                                               Usage      |
|=========================================================================================|
|    0   N/A  N/A          825682      G   /usr/lib/xorg/Xorg                      548MiB |
|    0   N/A  N/A          825910      G   /usr/bin/ksmserver                        7MiB |
|    0   N/A  N/A          825912      G   /usr/bin/kded5                            7MiB |
|    0   N/A  N/A          825913      G   /usr/bin/kwin_x11                       242MiB |
|    0   N/A  N/A          825975      G   ...it-kde-authentication-agent-1          7MiB |
|    0   N/A  N/A          826045      G   /usr/bin/kaccess                          7MiB |
|    0   N/A  N/A          826470      G   ...re=basic --ozone-platform=x11          7MiB |
|    0   N/A  N/A          826594      G   ...ersion=20250917-180036.632000        190MiB |
|    0   N/A  N/A          826675      G   ...ibexec/xdg-desktop-portal-kde          7MiB |
|    0   N/A  N/A          841932      G   /usr/bin/plasmashell                     48MiB |
|    0   N/A  N/A          877020      G   /usr/bin/konsole                          7MiB |
|    0   N/A  N/A         1005674      G   /usr/bin/krunner                         18MiB |
+-----------------------------------------------------------------------------------------+


## Screenshot: OpenWebUI Auth

Path: _logs/openwebui_auth.png
