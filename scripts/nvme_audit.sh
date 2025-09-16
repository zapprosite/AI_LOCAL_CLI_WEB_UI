#!/usr/bin/env bash
set -Eeuo pipefail
OUT="/data/stack/_out/nvme_audit_$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$OUT"

# LSBLK legível
{
  echo "== LSBLK =="
  lsblk -o NAME,TYPE,SIZE,FSTYPE,UUID,MOUNTPOINT,MODEL,SERIAL,TRAN,PKNAME -e7
} | tee "$OUT/lsblk.txt" >/dev/null

# LSBLK JSON
lsblk -J -o NAME,TYPE,SIZE,FSTYPE,UUID,MOUNTPOINT,MODEL,SERIAL,TRAN,PKNAME -e7 | tee "$OUT/lsblk.json" >/dev/null

# NVMe list
{
  echo "== NVME LIST =="
  if command -v nvme >/dev/null 2>&1; then nvme list; else echo "nvme-cli não instalado"; fi
} | tee "$OUT/nvme_list.txt" >/dev/null

# Identificadores por udev e sysfs
{
  echo "== IDENTIFIERS =="
  for d in /dev/nvme*n1 2>/dev/null; do
    [ -e "$d" ] || continue
    base="$(basename "$d")"
    echo "## $d"
    if command -v udevadm >/dev/null 2>&1; then
      udevadm info --query=property --name "$d" | grep -E '^(ID_SERIAL|ID_MODEL|ID_FS_UUID)=' || true
    fi
    [ -r "/sys/block/$base/device/serial" ] && echo "SYSFS_SERIAL=$(cat /sys/block/$base/device/serial)"
  done
} | tee "$OUT/ids.txt" >/dev/null

# Fstab atual
grep -E '^[^#]+' /etc/fstab 2>/dev/null | tee "$OUT/fstab.txt" >/dev/null || true

# Árvore de diretórios
{
  echo "# /data (nível 2)"
  if command -v tree >/dev/null 2>&1; then tree -a -L 2 /data; else echo "tree não instalado"; fi
} | tee "$OUT/tree.txt" >/dev/null

# Uso de disco
du -sh /data /data/ollama /data/qdrant /data/openwebui 2>/dev/null | tee "$OUT/du.txt" >/dev/null || true

echo "$OUT"
