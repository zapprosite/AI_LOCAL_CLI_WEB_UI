#!/usr/bin/env bash
set -euo pipefail

TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="/tmp/ai_syscheck_${TS}"
mkdir -p "$OUT"/{os,hw,fs,net,pkgs,python,docker,containers,audio,services,endpoints}

log(){ printf '%s\n' "$*" | tee -a "$OUT/summary.txt" >/dev/null; }
run(){ local f="$1"; shift || true; { "$@" 2>&1 || true; } | tee "$OUT/$f" >/dev/null; }

# ==== OS / Kernel / Sessão ====
run os/os_release.txt bash -lc 'cat /etc/os-release'
run os/kernel.txt      bash -lc 'uname -a'
run os/uptime.txt      bash -lc 'uptime -p'
run os/reboots.txt     bash -lc 'last -n 10 reboot || true'
run os/hostname.txt    bash -lc 'hostnamectl 2>&1 || true'
run os/env.txt         bash -lc 'printf "USER=%s\nUID=%s\n" "$USER" "$(id -u)"; echo "XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-}"; echo "DESKTOP=${XDG_CURRENT_DESKTOP:-}"'

# ==== Hardware / GPU ====
run hw/cpu.txt         bash -lc 'lscpu || true'
run hw/mem.txt         bash -lc 'free -h || true'
run hw/pci_gpu.txt     bash -lc 'lspci | grep -i -E "vga|nvidia" || true'
run hw/nvidia.txt      bash -lc 'command -v nvidia-smi >/dev/null && nvidia-smi || echo "nvidia-smi not found"'
run hw/nvidia_toolkit.txt bash -lc 'command -v nvidia-ctk >/dev/null && nvidia-ctk --version || echo "nvidia-ctk not found"'

# ==== Filesystems / Discos ====
run fs/lsblk.txt       bash -lc "lsblk -o NAME,FSTYPE,SIZE,TYPE,MOUNTPOINT,UUID"
run fs/df.txt          bash -lc "df -hT"
run fs/findmnt.txt     bash -lc "findmnt -no TARGET,SOURCE,FSTYPE,OPTIONS / /data /var/lib/docker 2>/dev/null || true"
run fs/trim.txt        bash -lc "command -v fstrim >/dev/null && { sudo fstrim -n -v / 2>/dev/null || true; sudo fstrim -n -v /data 2>/dev/null || true; } || true"
run fs/xfs_data.txt    bash -lc "[ -d /data ] && mount | grep ' /data ' | grep -q xfs && command -v xfs_info >/dev/null && xfs_info /data || echo 'xfs_info skip'"

# ==== Pacotes / APT ====
run pkgs/sources.txt   bash -lc "grep -R ^deb /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null || true"
run pkgs/policy.txt    bash -lc "apt-cache policy | sed -n '1,200p' || true"
run pkgs/holds.txt     bash -lc "apt-mark showhold || true"
run pkgs/dpkg_check.txt bash -lc "dpkg -C 2>&1 || true"

# ==== Python toolchain ====
run python/which.txt   bash -lc "command -v python3 || true; python3 --version 2>&1 || true"
run python/pips.txt    bash -lc "command -v pipx && pipx --version || true; python3 -m pip --version 2>&1 || true"
run python/venvs.txt   bash -lc 'if [ -e /data/stack/langgraph_agent/.venv ]; then echo "/data/stack/langgraph_agent/.venv"; stat -c "%U:%G %a" /data/stack/langgraph_agent/.venv; find /data/stack/langgraph_agent/.venv -maxdepth 1 -type d -printf "%f\n"; else echo "absent"; fi'

# ==== Docker / Compose ====
run docker/version.txt     bash -lc "docker version 2>&1 || true"
run docker/info.txt        bash -lc "docker info 2>&1 | sed -n '1,200p' || true"
run docker/compose_ver.txt bash -lc "docker compose version 2>&1 || true"
run docker/ps.txt          bash -lc "docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'"

# ==== Containers da stack ====
containers=(ai_stack-ollama-1 ai_stack-qdrant-1 ai_stack-litellm-1 ai_stack-openwebui-1 grafana prometheus loki promtail)
for c in "${containers[@]}"; do
  if command -v jq >/dev/null; then
    run "containers/${c}_inspect.txt" bash -lc "docker inspect \"$c\" 2>/dev/null | jq -r '[.[]|{Name:.Name,State:.State.Status,Health:(.State.Health.Status // \"none\"),Image:.Config.Image,Arch:(.Os+\"/\"+.Architecture),Mounts:[.Mounts[]?|{Dst:.Destination,Src:.Source}]}]' 2>/dev/null || echo not_found"
  else
    run "containers/${c}_inspect.txt" bash -lc "docker inspect -f '{{.Name}} {{.State.Status}} {{.Config.Image}}' \"$c\" 2>/dev/null || echo not_found"
  fi
  run "containers/${c}_logs.txt"    bash -lc "docker logs --tail=200 \"$c\" 2>&1 || true"
done

# ==== Endpoints locais ====
run endpoints/ollama.txt  bash -lc "command -v curl >/dev/null && curl -sS http://127.0.0.1:11434/api/tags | head -c 400 || echo 'OLLAMA_CHECK_SKIPPED'"
run endpoints/qdrant.txt  bash -lc "command -v curl >/dev/null && (curl -sS http://127.0.0.1:6333/readyz || curl -sS http://127.0.0.1:6333/livez || curl -sS http://127.0.0.1:6333/health) || echo 'QDRANT_CHECK_SKIPPED'"
run endpoints/litellm.txt bash -lc "command -v curl >/dev/null && curl -sS http://127.0.0.1:4000/v1/models | head -c 400 || echo 'LITELLM_CHECK_SKIPPED'"

# ==== Rede / Firewall ====
run net/ports.txt      bash -lc "ss -tulpen | grep -E ':(11434|4000|6333|3000)\\s' || true"
run net/ufw.txt        bash -lc "ufw status verbose 2>/dev/null || true"
run net/ip.txt         bash -lc "ip -br addr || true"
run net/route.txt      bash -lc "ip route || true"
run net/dns.txt        bash -lc "resolvectl status 2>/dev/null || cat /etc/resolv.conf || true"

# ==== Áudio (PipeWire) ====
run audio/pipewire.txt     bash -lc "systemctl --user --no-pager status pipewire.service 2>&1 || true"
run audio/wpctl.txt        bash -lc "command -v wpctl >/dev/null && wpctl status | sed -n '1,120p' || echo 'wpctl missing'"
run audio/pactl.txt        bash -lc "command -v pactl >/dev/null && { pactl info; pactl list sources short; } || echo 'pactl missing'"

# ==== Serviços do usuário / systemd ====
run services/user_units.txt   bash -lc "systemctl --user list-units --type=service --state=running 2>&1 | sed -n '1,200p' || true"
run services/system_units.txt bash -lc "systemctl list-units --type=service --state=running 2>&1 | sed -n '1,200p' || true"

# ==== Resumo rápido ====
OLL=$(grep -q '"models"' "$OUT/endpoints/ollama.txt" 2>/dev/null && echo up || echo down)
QDR=$(grep -q '"status":"ok"' "$OUT/endpoints/qdrant.txt" 2>/dev/null && echo up || echo down)
LTE=$(grep -Eqi '"object"|"models"' "$OUT/endpoints/litellm.txt" 2>/dev/null && echo up || echo down)
PYV=$(grep -Eo 'Python 3\.[0-9.]+' "$OUT/python/which.txt" | head -n1 || true)
VENV_OWN="ok"; if [ -e /data/stack/langgraph_agent/.venv ]; then OWN="$(stat -c '%U' /data/stack/langgraph_agent/.venv 2>/dev/null || echo unknown)"; [ "$OWN" = "$USER" ] || VENV_OWN="mismatch"; fi

log "OUT_DIR=$OUT"
log "ARCHIVE=$OUT.tar.gz"
log "OS: $(. /etc/os-release; echo $PRETTY_NAME) | Kernel: $(uname -r)"
log "Python: ${PYV:-unknown} | .venv ownership: ${VENV_OWN}"
log "Endpoints → ollama:$OLL qdrant:$QDR litellm:$LTE"
tar -C /tmp -czf "$OUT.tar.gz" "$(basename "$OUT")" 2>/dev/null || true

echo "=== SUMMARY ==="
cat "$OUT/summary.txt"
