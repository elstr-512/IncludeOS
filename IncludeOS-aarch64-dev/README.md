# AARCH64

- The current target is: `QEMU Arm System emulator - ‘virt’ generic virtual
platform`
- Every aarch64 source file in use are in: `src/platform/aarch64_qemu_virt`

## build aarch64 Includeos
```sh
# default build
nix-shell develop-arm.nix

# if you have enabled and wanna use ccache
nix-shell develop-arm.nix --arg withCcache true

# and if you want to use zsh instead of bash
nix-shell develop-arm.nix --arg withCcache true --arg useZsh true
```

This sets up the `/boot` directory with
- hello_includeos.elf.bin (ELF 64-bit LSB executable, ARM aarch64)
- u-boot.bin (optional boot loader)
- Makefile (not for making :p, just for cmds)

In the boot directory, use the different make cmds.

## QEMU

```sh
# stop qemu execution with
Ctrl-a x
```

## Issues

- [ ] `serial1.cpp : kprintf()`

Alignment fault.
https://developer.arm.com/documentation/102376/0200/Alignment-and-endianness/Alignment

Unaligned accesses are allowed to addresses marked as Normal, but not to Device
regions. An unaligned access to a Device region will trigger an exception
(alignment fault).

**Since the MMU isn't configured (or enabled), all of memory is considered
device region. On QEMU-virt, the device region goes from 0x0 - 0x40000000, and
normal memory should start at 0x40000000**
