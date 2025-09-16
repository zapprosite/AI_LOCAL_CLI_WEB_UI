#!/usr/bin/env bash
set -Eeuo pipefail

rule_path="/etc/udev/rules.d/99-nvme-aliases.rules"

# Descobrir device raiz (/) e de /data
ROOT_SRC="$(findmnt -no SOURCE / || true)"
DATA_SRC="$(findmnt -no SOURCE /data || true)"

# Função: normalizar para disco (remove partição pN)
parent_disk() {
  local src="$1"
  if [[ "$src" =~ ^/dev/nvme[0-9]+n[0-9]+p[0-9]+$ ]]; then
    echo "${src%p*[0-9]}"
  else
    # tenta via lsblk
    lsblk -no PKNAME "$src" 2>/dev/null | awk '{print "/dev/"$1}' || echo "$src"
  fi
}

ROOT_DISK="$(parent_disk "${ROOT_SRC:-}")"
DATA_DISK="$(parent_disk "${DATA_SRC:-}")"

get_serial() {
  local dev="$1"
  # Tenta via udevadm
  local s
  s="$(udevadm info --query=property --name "$dev" 2>/dev/null | awk -F= '/^ID_SERIAL=/{print $2; exit}')"
  if [ -z "$s" ] && command -v nvme >/dev/null 2>&1; then
    s="$(nvme id-ctrl "$dev" 2>/dev/null | awk '/^sn[[:space:]]*:/ {print $3; exit}')"
  fi
  echo "$s"
}

SER_OS="$( [ -n "${ROOT_DISK:-}" ] && get_serial "$ROOT_DISK" || echo "" )"
SER_DATA="$( [ -n "${DATA_DISK:-}" ] && get_serial "$DATA_DISK" || echo "" )"

echo "ROOT_SRC=${ROOT_SRC:-none}"
echo "ROOT_DISK=${ROOT_DISK:-none} SERIAL_OS=${SER_OS:-none}"
echo "DATA_SRC=${DATA_SRC:-none}"
echo "DATA_DISK=${DATA_DISK:-none} SERIAL_DATA=${SER_DATA:-none}"

# Gera regras apenas para NVMe com serial conhecido
{
  echo '# Regras estáveis para NVMe — geradas automaticamente'
  echo '# /dev/nvme_os -> disco que contém /'
  echo '# /dev/nvme_data -> disco que contém /data'
  [ -n "$SER_OS" ] && cat <<R1
SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", ENV{ID_SERIAL}=="$SER_OS", SYMLINK+="nvme_os"
R1
  [ -n "$SER_DATA" ] && cat <<R2
SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", ENV{ID_SERIAL}=="$SER_DATA", SYMLINK+="nvme_data"
R2
} | sudo tee "$rule_path" >/dev/null

sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=block

# Mostra resultado
ls -l /dev/nvme_os /dev/nvme_data 2>/dev/null || true
echo "REGRAS: $rule_path"
