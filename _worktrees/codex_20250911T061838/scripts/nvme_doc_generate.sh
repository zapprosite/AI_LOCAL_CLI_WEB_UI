#!/usr/bin/env bash
set -Eeuo pipefail
DOC="/data/stack/ai_gateway/docs/NVME_MAP.md"

to_disk(){ case "$1" in (/dev/nvme*n*p*) echo "${1%p*}";; (*) lsblk -no PKNAME "$1" 2>/dev/null | awk '{print "/dev/"$1}';; esac; }
serial_of(){ b="$(basename "$1")"; [ -r "/sys/block/$b/device/serial" ] && cat "/sys/block/$b/device/serial" || echo ""; }
uuid_of(){ blkid -s UUID -o value "$1" 2>/dev/null || echo ""; }

ROOT_SRC="$(findmnt -no SOURCE / || true)"
DATA_SRC="$(findmnt -no SOURCE /data || true)"
ROOT_DISK="$(to_disk "$ROOT_SRC")"; DATA_DISK="$(to_disk "$DATA_SRC")"
S_OS="$(serial_of "$ROOT_DISK")"; S_DATA="$(serial_of "$DATA_DISK")"
U_OS="$(uuid_of "$ROOT_SRC")"; U_DATA="$(uuid_of "$DATA_SRC")"

cat >"$DOC" <<MD
# Inventário NVMe e regras

## Symlinks udev
- \`/dev/nvme_os\` → **$ROOT_DISK**  (serial **$S_OS**)
- \`/dev/nvme_data\` → **$DATA_DISK** (serial **$S_DATA**)

Regras ativas: \`/etc/udev/rules.d/99-nvme-aliases.rules\`
\`\`\`
KERNEL=="nvme*n1", SUBSYSTEM=="block", ATTRS{serial}=="$S_OS",   SYMLINK+="nvme_os"
KERNEL=="nvme*n1", SUBSYSTEM=="block", ATTRS{serial}=="$S_DATA", SYMLINK+="nvme_data"
\`\`\`

## Montagens atuais
- / → $ROOT_SRC
- /data → $DATA_SRC

## fstab (sugestão por UUID)
\`\`\`fstab
${U_OS:+UUID=$U_OS   /      $(findmnt -no FSTYPE /)   defaults,errors=remount-ro   0 1}
${U_DATA:+UUID=$U_DATA   /data  $(findmnt -no FSTYPE /data 2>/dev/null || echo xfs)   defaults   0 2}
\`\`\`

## Árvore /data (nível 2)
Arquivo gerado com \`tree -a -L 2 /data\`. Consulte \`/data/stack/_out\`.
MD

echo "$DOC"
