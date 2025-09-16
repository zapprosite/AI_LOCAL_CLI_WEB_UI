#!/usr/bin/env bash
set -Eeuo pipefail
echo "== SYMLINKS =="; ls -l /dev/nvme_os /dev/nvme_data || true
echo "== RULES =="; sed -n '1,200p' /etc/udev/rules.d/99-nvme-aliases.rules || true
echo "== MOUNTS =="; findmnt -o TARGET,SOURCE,FSTYPE,OPTIONS / /data || true
echo "== IDS =="
for d in /dev/nvme*n1; do
  [ -e "$d" ] || continue
  b="$(basename "$d")"
  printf "## %s  " "$d"
  if [ -r "/sys/block/$b/device/serial" ]; then
    printf "serial=%s\n" "$(tr -d '\r' < "/sys/block/$b/device/serial")"
  else
    echo
  fi
done
