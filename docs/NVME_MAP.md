# NVME_MAP

> **Status**: synchronized  
> **Host**: zappro
> **Last Audited**: 2025-09-16T06:04:13-03:00
> **Stack Summary**:  
> ```
> SUMMARY :4000=200 :4001=200 MODELS4000=[fast,light,heavy] MODELS4001=[code.hybrid,docs.hybrid,search.hybrid,code.remote,docs.remote,search.remote,code.router,docs.router,search.router,openai.gpt5] fast=200 code.router=200 code.hybrid.local=200 code.hybrid.fb=200 openwebui="ai_gateway-openwebui-1	0.0.0.0:3000->8080/tcp, [::]:3000->8080/tcp" qdrant=200
> ```
> (audit fail)
> (audit fail)
> (audit fail)

## Overview
Short purpose of this document in the AI local stack (GPU + LiteLLM Router + Ollama + OpenWebUI + Qdrant). Keep it concise and actionable.

## Architecture Context
- Router (ports 4000/4001), hybrids: code/docs/search → fallback openai/gpt-5  
- Local models via Ollama (qwen2.5-coder:14b etc.)
- OpenWebUI as OpenAI-compatible client  
- Vector store: Qdrant

## Operations (Terminal-only)
- Health: `ai_gateway/WAIT_HEALTH.sh`  
- Smoke: `ai_gateway/SMOKE_NOW.sh`  
- Final audit: `ai_gateway/FINAL_AUDIT.sh`

## How to Use
Step-by-step relevant to this document. Example requests, env vars, compose overlays.

## Troubleshooting
Common pitfalls + quick commands.

## Legacy Notes
(Original content preserved below)

----
## Legacy Notes (raw)

# Inventário NVMe e regras

## Symlinks udev
- `/dev/nvme_os` → **/dev/nvme1n1**  (serial **50026B768716D856    **)
- `/dev/nvme_data` → **/dev/nvme0n1** (serial **2404E892A74D        **)

Regras ativas: `/etc/udev/rules.d/99-nvme-aliases.rules`
```
KERNEL=="nvme*n1", SUBSYSTEM=="block", ATTRS{serial}=="50026B768716D856    ",   SYMLINK+="nvme_os"
KERNEL=="nvme*n1", SUBSYSTEM=="block", ATTRS{serial}=="2404E892A74D        ", SYMLINK+="nvme_data"
```

## Montagens atuais
- / → /dev/nvme1n1p2
- /data → /dev/nvme0n1p1

## fstab (sugestão por UUID)
```fstab
UUID=7d203a1a-4008-4dbe-acf3-c8132950320e   /      ext4   defaults,errors=remount-ro   0 1
UUID=80f2540c-8642-4263-b7d7-93d19ea66ae9   /data  xfs   defaults   0 2
```

## Árvore /data (nível 2)
Arquivo gerado com `tree -a -L 2 /data`. Consulte `/data/stack/_out`.
