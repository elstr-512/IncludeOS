
TARGET := hello_includeos.elf.bin

# cortex-a53 ? -a57

run-kernel:
	@echo -e "[RUN] Launching QEMU\n"
	@qemu-system-aarch64 -m 1024M -machine virt -cpu cortex-a53 \
		-nographic -kernel $(TARGET)

run-uboot:
	@echo -e "[RUN] Launching QEMU (w. uboot)\n"
	@echo "go 0x40201000"
	@qemu-system-aarch64 -m 1024M -machine virt -cpu cortex-a53 \
		-bios u-boot.bin -device loader,file=$(TARGET),addr=0x40200000 -nographic

debug-kernel:
	@echo -e "[DBG] Launching QEMU + GDB\n"
	@echo 'gdb $(TARGET) -ex "target extended-remote :1234" -ex "break _start"'
	@qemu-system-aarch64 -s -S -m 1024M -machine virt -cpu cortex-a53 \
		-nographic -kernel $(TARGET) -d int,mmu -D qemu.log

debug-uboot:
	@echo -e "[DBG] Launching QEMU (w. uboot) + GDB\n"
	@echo "go 0x40201000"
	@echo 'gdb $(TARGET) -ex "target extended-remote :1234" -ex "break _start"'
	@qemu-system-aarch64 -s -S -m 1024M -machine virt -cpu cortex-a53 \
		-bios u-boot.bin -device loader,file=$(TARGET),addr=0x40200000 \
		-nographic -d int,mmu -D qemu.log

dump-dtb:
	@qemu-system-aarch64 -machine virt,dumpdtb=dtb-out.dtb

nix-repl:
	@nix repl -f '<nixpkgs>' -I nixpkgs=channel:nixos-23.11
