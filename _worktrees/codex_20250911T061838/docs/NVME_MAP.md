# Inventário NVMe e regras

## Symlinks udev
- `/dev/nvme_os` → **/dev/nvme1n1**  (serial **50026B768716D856    **)
- `/dev/nvme_data` → **/dev/nvme0n1** (serial **2404E892A74D        **)

Regras ativas: `/etc/udev/rules.d/99-nvme-aliases.rules`
```
KERNEL=="nvme*n1", SUBSYSTEM=="block", ATTRS{serial}=="50026B768716D856    ",   SYMLINK+="nvme_os"
KERNEL=="nvme*n1", SUBSYSTEM=="block", ATTRS{serial}=="2404E892A74D        ", SYMLINK+="nvme_data"
```

## Montagens atuais
- / → /dev/nvme1n1p2
- /data → /dev/nvme0n1p1

## fstab (sugestão por UUID)
```fstab
UUID=7d203a1a-4008-4dbe-acf3-c8132950320e   /      ext4   defaults,errors=remount-ro   0 1
UUID=80f2540c-8642-4263-b7d7-93d19ea66ae9   /data  xfs   defaults   0 2
```

## Árvore /data (nível 2)
Arquivo gerado com `tree -a -L 2 /data`. Consulte `/data/stack/_out`.
