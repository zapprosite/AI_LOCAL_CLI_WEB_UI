#!/usr/bin/env bash
set -Eeuo pipefail
OUT="/data/stack/_out/fstab_suggest_$(date -u +%Y%m%dT%H%M%SZ).txt"
ROOT_SRC="$(findmnt -no SOURCE / || true)"
DATA_SRC="$(findmnt -no SOURCE /data || true)"
uuid_of(){ blkid -s UUID -o value "$1" 2>/dev/null || echo ""; }

UR="$( [ -n "$ROOT_SRC" ] && uuid_of "$ROOT_SRC" || echo "" )"
UD="$( [ -n "$DATA_SRC" ] && uuid_of "$DATA_SRC" || echo "" )"

{
  echo "# fstab suggestions (não aplicado automaticamente)"
  [ -n "$UR" ] && echo "UUID=$UR   /      $(findmnt -no FSTYPE /)   defaults,errors=remount-ro   0 1"
  [ -n "$UD" ] && echo "UUID=$UD   /data  $(findmnt -no FSTYPE /data 2>/dev/null || echo xfs)   defaults   0 2"
} | tee "$OUT"

echo "$OUT"
