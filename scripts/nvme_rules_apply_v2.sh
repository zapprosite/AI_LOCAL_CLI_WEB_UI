#!/usr/bin/env bash
set -Eeuo pipefail
rule_path="/etc/udev/rules.d/99-nvme-aliases.rules"

to_disk(){ local s="${1:-}"; [[ "$s" =~ ^/dev/nvme[0-9]+n[0-9]+p ]] && echo "${s%p*}" || lsblk -no PKNAME "$s" 2>/dev/null | awk '{print "/dev/"$1}'; }
serial(){ nvme id-ctrl "$1" 2>/dev/null | awk '/^sn[[:space:]]*:/ {print $3; exit}'; }

root_src="$(findmnt -no SOURCE / || true)"
data_src="$(findmnt -no SOURCE /data || true)"
root_disk="$(to_disk "$root_src")"
data_disk="$(to_disk "$data_src")"
S_OS="$( [ -n "$root_disk" ] && serial "$root_disk" || echo )"
S_DATA="$( [ -n "$data_disk" ] && serial "$data_disk" || echo )"

echo "root_disk=$root_disk sn=$S_OS"
echo "data_disk=$data_disk sn=$S_DATA"

{
  echo '# NVMe aliases by controller serial — generated'
  [ -n "$S_OS" ]   && echo 'KERNEL=="nvme*n1", SUBSYSTEM=="block", ATTRS{serial}=="'"$S_OS"'", SYMLINK+="nvme_os"'
  [ -n "$S_DATA" ] && echo 'KERNEL=="nvme*n1", SUBSYSTEM=="block", ATTRS{serial}=="'"$S_DATA"'", SYMLINK+="nvme_data"'
} | sudo tee "$rule_path" >/dev/null

sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=block

ls -l /dev/nvme_os /dev/nvme_data 2>/dev/null || true
echo "REGRAS: $rule_path"
