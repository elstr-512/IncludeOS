# ────────────────────────────────
# This makefile is just for running
# repetitive commands.
# Could instead be a justfile.
# .


# ────────────────────────────────
# Utils
# .
dump-dtb:
	@echo -e "[DTB] Dump QEMU device-tree-blob\n"
	@qemu-system-aarch64 -machine virt,dumpdtb=dtb-out.dtb
	@dtc dtb-out.dtb -o dtb-out.txt
	@echo "[DTB] human readable dtb dumped to dtb-out.txt"

nix-repl:
	@echo -e "[NIX] Opening nix repl \n"
	@nix repl -f '<nixpkgs>' -I nixpkgs=channel:nixos-25.05

# ────────────────────────────────
# qemu booting
# .

TARGET := hello_includeos.elf.bin

kernel:
	@echo -e "[RUN] Launching QEMU with '-kernel flag'\n"
	qemu-system-aarch64 -m 1024M -machine virt -cpu cortex-a53 -nographic \
		-kernel $(TARGET) \
		| tee kernel.log

uboot:
	@echo -e "[RUN] Launching QEMU (w. uboot as bios)\n"
	@echo -e "[GUIDE] Wait until uboot SHELL opens, then"
	@echo -e "[GUIDE] use the 'go' cmd to start application"
	@echo -e "[GUIDE] found at address of the <_start> label \n"
	aarch64-unknown-linux-musl-objdump -d hello_includeos.elf.bin | head | tail -n 5
	qemu-system-aarch64 -m 1024M -machine virt -cpu cortex-a53 -nographic \
		-bios u-boot.bin -kernel $(TARGET) \
		| tee uboot.log

image-boot: $(TARGET)
	@aarch64-unknown-linux-musl-objcopy -O binary $(TARGET) includeos.img
	@qemu-system-aarch64 -m 1024M -machine virt -cpu cortex-a53 -nographic \
		-bios u-boot.bin -kernel includeos.img \

# ────────────────────────────────
# qemu debug booting
# .

debug:
	@echo -e "[DGB] Launching QEMU with '-kernel flag' AND waiting for debugger\n"
	qemu-system-aarch64 -s -S -m 1024M -machine virt -cpu cortex-a53 -nographic \
		-kernel $(TARGET) \
		-d int,mmu -D qemu.log

# ────────────────────────────────
# debug attach
# .

gdb-attach:
	@echo -e "[DGB] attaching gdb to qemu instance\n"
	gdb $(TARGET) -ex "target extended-remote :1234" -ex "break _start"

NIX_BUILD_ROOT  := /build/source
PROJECT_ROOT    := ?
SUBSTITUTE_ROOT := set substitute-path $(NIX_BUILD_ROOT) $(PROJECT_ROOT)

gef-attatch:
	@echo -e "[DGB] attaching gdb to qemu instance\n"
	gdb $(TARGET) -ex "$(SUBSTITUTE_ROOT)" -ex "gef-remote --qemu-user localhost 1234" -ex "break _start"

