#!/usr/bin/env bash
set -Eeuo pipefail
RULE="/etc/udev/rules.d/99-nvme-aliases.rules"

to_disk() {
  local src="$1"
  case "$src" in
    /dev/nvme*n*p*) echo "${src%p*}";;
    *) lsblk -no PKNAME "$src" 2>/dev/null | awk '{print "/dev/"$1}';;
  esac
}

serial_sysfs() {
  # lê /sys/block/<nvmeXnY>/device/serial
  local dev="$1" base; base="$(basename "$dev")"
  [ -r "/sys/block/$base/device/serial" ] && cat "/sys/block/$base/device/serial" || echo ""
}

ROOT_SRC="$(findmnt -no SOURCE / || true)"
DATA_SRC="$(findmnt -no SOURCE /data || true)"
ROOT_DISK="$(to_disk "${ROOT_SRC:-}")"
DATA_DISK="$(to_disk "${DATA_SRC:-}")"

S_OS="$( [ -n "$ROOT_DISK" ] && serial_sysfs "$ROOT_DISK" || echo )"
S_DATA="$( [ -n "$DATA_DISK" ] && serial_sysfs "$DATA_DISK" || echo )"

echo "ROOT_SRC=${ROOT_SRC:-none}"
echo "ROOT_DISK=${ROOT_DISK:-none} SYSFS_SERIAL_OS=${S_OS:-none}"
echo "DATA_SRC=${DATA_SRC:-none}"
echo "DATA_DISK=${DATA_DISK:-none} SYSFS_SERIAL_DATA=${S_DATA:-none}"

{
  echo '# NVMe aliases by controller serial (sysfs) — generated'
  [ -n "$S_OS" ]   && echo 'KERNEL=="nvme*n1", SUBSYSTEM=="block", ATTRS{serial}=="'"$S_OS"'", SYMLINK+="nvme_os"'
  [ -n "$S_DATA" ] && echo 'KERNEL=="nvme*n1", SUBSYSTEM=="block", ATTRS{serial}=="'"$S_DATA"'", SYMLINK+="nvme_data"'
} | sudo tee "$RULE" >/dev/null

sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=block

ls -l /dev/nvme_os /dev/nvme_data 2>/dev/null || true
echo "REGRAS: $RULE"
