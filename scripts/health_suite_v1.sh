#!/usr/bin/env bash
set -euo pipefail

TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="/tmp/health_${TS}"
mkdir -p "$OUT"

section(){ echo -e "\n=== $1 ==="; }

# ---- SISTEMA (Ubuntu + KDE + Audio + Chrome) ----
section "OS / Kernel / GPU"
uname -a | tee -a "$OUT/os.txt"
lsb_release -a 2>/dev/null | tee -a "$OUT/os.txt" || true
nvidia-smi -L 2>/dev/null | tee -a "$OUT/gpu.txt" || true
nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null | tee -a "$OUT/gpu.txt" || true

section "Discos e montagem /data"
lsblk -o NAME,FSTYPE,SIZE,TYPE,MOUNTPOINT,UUID | tee "$OUT/lsblk.txt"
findmnt -R -no TARGET,SOURCE,FSTYPE,OPTIONS / /data /var/lib/docker 2>/dev/null | tee "$OUT/findmnt.txt"
df -h / /data | tee "$OUT/df.txt"

section "Pacotes chave"
python3 --version 2>&1 | tee "$OUT/python.txt" || true
node -v 2>&1 | tee -a "$OUT/node.txt" || true
pnpm -v 2>&1 | tee -a "$OUT/node.txt" || true

section "KDE Plasma / Display / Login"
dpkg -l | grep -E 'kde-plasma-desktop|plasma-desktop|sddm' || true
systemctl is-active sddm 2>/dev/null || true
loginctl list-sessions 2>/dev/null || true

section "Audio PipeWire"
systemctl --user status pipewire 2>/dev/null | sed -n '1,6p' || true
systemctl --user status wireplumber 2>/dev/null | sed -n '1,6p' || true
pactl info 2>/dev/null | sed -n '1,20p' || true
pactl list short sinks 2>/dev/null || true
pactl list short sources 2>/dev/null || true
wpctl status 2>/dev/null | sed -n '1,80p' || true

section "Google Chrome"
command -v google-chrome && google-chrome --version || echo "google-chrome: not found"
[ -d /etc/opt/chrome/policies/managed ] && { echo "-- policies managed --"; ls -l /etc/opt/chrome/policies/managed; for f in /etc/opt/chrome/policies/managed/*.json; do [ -f "$f" ] && { echo ">>> $f"; sed -n '1,120p' "$f"; }; done; } || true

section "Firewall e portas"
ufw status verbose 2>/dev/null || true
ss -tulpen | grep -E ':(11434|4000|6333|3000)\s' || true

# ---- STACK (Docker + Compose + Endpoints) ----
section "Docker / Compose"
docker --version
docker compose version || true
echo "-- Root Dir --"; docker info 2>/dev/null | grep -i "Docker Root Dir" || true

section "Containers alvo"
docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}' | grep -E '^litellm$|ai_stack-(ollama|qdrant|openwebui)-1|^NAMES' || true

section "Redes e DNS"
docker network ls --format '{{.Name}}' | grep -E '^ai_stack_net$|^bridge$' || true
for c in litellm ai_stack-ollama-1 ai_stack-qdrant-1; do
  echo "--- $c ---"
  docker inspect -f '{{.Name}} -> {{range $$k,$$v := .NetworkSettings.Networks}}{{printf "%s " $$k}}{{end}}' "$c" 2>/dev/null || true
done

section "Mounts principais"
for c in litellm ai_stack-ollama-1 ai_stack-qdrant-1; do
  echo "--- $c ---"
  docker inspect -f '{{range .Mounts}}{{.Destination}}<-{{.Source}};{{end}}' "$c" 2>/dev/null || true
done

section "Endpoints host"
echo "-- qdrant --";  curl -m 3 -sfS 127.0.0.1:6333/readyz || curl -m 3 -sfS 127.0.0.1:6333/livez || echo "qdrant_fail"
echo "-- ollama --";  curl -m 3 -sfS 127.0.0.1:11434/api/tags | head -c 200 || echo "ollama_fail"
echo "-- litellm --"; curl -m 3 -sfS 127.0.0.1:4000/v1/models | head -c 400 || echo "litellm_fail"

section "Resumo"
echo "OUT_DIR=$OUT"
