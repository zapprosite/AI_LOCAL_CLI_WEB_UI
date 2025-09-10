#!/usr/bin/env bash
set -Eeuo pipefail
RULE="/etc/udev/rules.d/99-nvme-aliases.rules"

to_disk(){ case "$1" in (/dev/nvme*n*p*) echo "${1%p*}";; (*) lsblk -no PKNAME "$1" 2>/dev/null | awk '{print "/dev/"$1}';; esac; }
trim(){ sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' ; }

ROOT_SRC="$(findmnt -no SOURCE / || true)";   ROOT_DISK="$(to_disk "$ROOT_SRC")"
DATA_SRC="$(findmnt -no SOURCE /data || true)"; DATA_DISK="$(to_disk "$DATA_SRC")"

s_os="";   [ -n "$ROOT_DISK" ] && s_os="$(tr -d '\r' < /sys/block/$(basename "$ROOT_DISK")/device/serial | trim)"
s_data=""; [ -n "$DATA_DISK" ] && s_data="$(tr -d '\r' < /sys/block/$(basename "$DATA_DISK")/device/serial | trim)"

{
  echo '# NVMe aliases by controller serial (wildcard) — generated'
  [ -n "$s_os" ]   && echo 'KERNEL=="nvme*n1", SUBSYSTEM=="block", ATTRS{serial}=="*'"$s_os"'*", SYMLINK+="nvme_os"'
  [ -n "$s_data" ] && echo 'KERNEL=="nvme*n1", SUBSYSTEM=="block", ATTRS{serial}=="*'"$s_data"'*", SYMLINK+="nvme_data"'
} | sudo tee "$RULE" >/dev/null

sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=block
ls -l /dev/nvme_os /dev/nvme_data 2>/dev/null || true
echo "REGRAS: $RULE"
