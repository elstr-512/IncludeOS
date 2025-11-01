TARGET := hello_includeos.elf.bin

dump-dtb:
	@echo -e "[DTB] Dump QEMU device-tree-blob\n"
	@qemu-system-aarch64 -machine virt,dumpdtb=dtb-out.dtb
	@dtc dtb-out.dtb -o dtb-out.txt
	@echo "[DTB] human readable dtb dumped to dtb-out.txt"

nix-repl:
	@echo -e "[NIX] Opening nix repl \n"
	@nix repl -f '<nixpkgs>' -I nixpkgs=channel:nixos-23.11

kernel:
	@echo -e "[RUN] Launching QEMU with '-kernel flag'\n"
	qemu-system-aarch64 -m 1024M -machine virt -cpu cortex-a53 -nographic \
		-kernel $(TARGET) \

uboot:
	@echo -e "[RUN] Launching QEMU (w. uboot as bios)\n"
	@echo -e "[GUIDE] Wait until uboot SHELL opens, then"
	@echo -e "[GUIDE] use the 'go' cmd to start application"
	@echo -e "[GUIDE] found at address of the <_start> label \n"
	objdump -d hello_includeos.elf.bin | head | tail -n 5
	qemu-system-aarch64 -m 1024M -machine virt -cpu cortex-a53 -nographic \
		-bios u-boot.bin -kernel $(TARGET) \

debug:
	@echo -e "[DGB] Launching QEMU with '-kernel flag' AND waiting for debugger\n"
	qemu-system-aarch64 -s -S -m 1024M -machine virt -cpu cortex-a53 -nographic \
		-kernel $(TARGET) \
		-d int,mmu -D qemu.log

gdb-attatch:
	@echo -e "[DGB] attaching gdb to qemu instance\n"
	gdb $(TARGET) -ex "target extended-remote :1234" -ex "break _start"
