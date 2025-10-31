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
		-bios u-boot.bin -device loader,file=$(TARGET) -nographic

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

aaaaa-:
	objcopy -O binary $(TARGET) $(TARGET).img
	@qemu-system-aarch64 --machine virt -cpu cortex-a53 -bios u-boot.bin -nographic -kernel $(TARGET).img \
		-d int,mmu -D qemu.log

############### HMMMMMMMMMM ###############
aaaaa-kernel:
	@echo -e "[RUN] Launching QEMU\n"
	qemu-system-aarch64 -m 1024M -machine virt -cpu cortex-a53 -nographic \
		-kernel $(TARGET) \
		-d int,mmu -D qemu.log

aaaaa-uboot:
	@echo -e "[RUN] Launching QEMU (w. uboot)\n"
	@objdump -d hello_includeos.elf.bin | head | tail -n 5
	qemu-system-aarch64 -m 1024M -machine virt -cpu cortex-a53 -nographic \
		-bios u-boot.bin -kernel $(TARGET) \
		-d int,mmu -D qemu.log

aaaaa-kernel-debug:
	@echo -e "[DBG] Launching QEMU\n"
	qemu-system-aarch64 -s -S -m 1024M -machine virt -cpu cortex-a53 -nographic \
		-kernel $(TARGET) \
		-d int,mmu -D qemu.log

aaaaa-gdb-attatch:
	gdb $(TARGET) -ex "target extended-remote :1234" -ex "break _start"

############### HMMMMMMMMMM ###############

bbbbb:
	objcopy -O binary $(TARGET) $(TARGET).img
	@qemu-system-aarch64 -s -S --machine virt -cpu cortex-a53 -bios u-boot.bin -nographic -kernel $(TARGET).img

ccccc:
	gdb $(TARGET) -ex "target extended-remote :1234" -ex "break _start"
