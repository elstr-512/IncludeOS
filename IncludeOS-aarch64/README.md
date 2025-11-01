# AARCH64

- The current target is: `QEMU Arm System emulator - ‘virt’ generic virtual platform`
- Source files are in dir: `src/platform/aarch64_qemu_virt`


## boot example service
build example service and enter develop-shell:
```sh
nix-shell develop-arm.nix --arg withCcache true
```

this creates a shell and a `/boot` directory with
- hello_includeos.elf.bin (ELF 64-bit LSB executable, ARM aarch64)
- u-boot.bin
- Makefile (not for making :p, just autocomplete for cmds)

go into the boot directory and use the different `make ~cmds` :p

## QEMU

just stop qemu with

```
Ctrl-a x
```

if any there are any qemu instances that didn't exit and messing with
launching new instances just find it and kill it :p (pattern that searches for process name longer than 15 characters will result in zero matches)
```sh
pkill qemu-system-aa
```

## nix usage
build aarch64 IncludeOS derivation:
```sh
nix-build --arg withCcache true
```

develop-shell, it build the example service:
```sh
nix-shell develop-arm.nix --arg withCcache true
```

develop-shell, skips build, just a shell with useful tools:
```sh
nix-shell develop-arm.nix --arg withCcache true --arg skipBuild true
```

develop-shell, use zsh:
```sh
nix-shell develop-arm.nix --arg withCcache true --arg useZsh true
```

develop-shell, skip build, use zsh:
```sh
nix-shell develop-arm.nix --arg withCcache true --arg useZsh true --arg skipBuild true
```
