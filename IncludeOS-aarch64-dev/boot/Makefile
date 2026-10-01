# ────────────────────────────────
# This makefile is just for running
# repetitive commands.
# Could instead be a justfile.
# .

MACHINE_GICv2 := virt
MACHINE_GICv3 := virt,gic-version=3

MACHINE_FLAGS := $(MACHINE_GICv3)

CPU_FLAGS := cortex-a76

# ────────────────────────────────
# Utils
# .
dump-dtb:
	@echo -e "[DTB] Dump QEMU device-tree-blob"

	@qemu-system-aarch64 \
		-m 256M \
		-cpu $(CPU_FLAGS) \
		-machine $(MACHINE_FLAGS),dumpdtb=dtb-out.dtb

	@dtc dtb-out.dtb -o dtb-out.txt
	@rm dtb-out.dtb
	@echo "[DTB] human readable dtb dumped to dtb-out.txt"

help-qemu:
	@echo -e "[HELP]\n"
	@qemu-system-aarch64 \
		-m 256M \
		-cpu $(CPU_FLAGS) \
		-machine $(MACHINE_FLAGS),help

nix-repl:
	@echo -e "[NIX] Opening nix repl \n"
	@nix repl -f '<nixpkgs>' -I nixpkgs=channel:nixos-25.05

# ────────────────────────────────
# qemu booting
# .

TARGET := hello_includeos.elf.bin

kernel:
	@echo -e "[RUN] Launching QEMU with '-kernel flag'\n"
	qemu-system-aarch64 \
		-m 2G \
		-machine $(MACHINE_FLAGS) \
		-cpu $(CPU_FLAGS) \
		-nographic \
		-kernel $(TARGET) \
		-d int,mmu -D qemu.log \
		| tee kernel.log

uboot:
	@echo -e "[RUN] Launching QEMU (w. uboot as bios)\n"
	@echo -e "[GUIDE] Wait until uboot SHELL opens, then"
	@echo -e "[GUIDE] use the 'go' cmd to start application"
	@echo -e "[GUIDE] found at address of the <_start> label \n"
	aarch64-unknown-linux-musl-objdump -d hello_includeos.elf.bin | head | tail -n 5
	qemu-system-aarch64 \
		-m 2G \
		-machine $(MACHINE_FLAGS) \
		-cpu $(CPU_FLAGS) \
		-nographic \
		-kernel $(TARGET) \
		-bios u-boot.bin \
		| tee uboot.log

image-boot: $(TARGET)
	@aarch64-unknown-linux-musl-objcopy -O binary $(TARGET) includeos.img
	@qemu-system-aarch64 \
		-m 2G \
		-machine $(MACHINE_FLAGS) \
		-cpu $(CPU_FLAGS) \
		-nographic \
		-kernel includeos.img \
		-bios u-boot.bin

# ────────────────────────────────
# qemu debug booting
# .

debug:
	@echo -e "[DGB] Launching QEMU with '-kernel flag' AND waiting for debugger\n"
	qemu-system-aarch64 \
		-s -S \
		-m 2G \
		-machine $(MACHINE_FLAGS) \
		-cpu $(CPU_FLAGS) \
		-nographic \
		-kernel $(TARGET) \
		-d int,mmu -D qemu.log

# ────────────────────────────────
# debug attach
# .

gdb-attach:
	@echo -e "[DGB] attaching gdb to qemu instance\n"
	gdb $(TARGET) -ex "target extended-remote :1234" -ex "break _start"

NIX_BUILD_ROOT  := /build/source
PROJECT_ROOT    := /home/ee/workspace/IncludeOS-dir/IncludeOS-elstr-512-clean
SUBSTITUTE_ROOT := set substitute-path $(NIX_BUILD_ROOT) $(PROJECT_ROOT)

gef-attatch:
	@echo -e "[DGB] attaching gdb to qemu instance\n"
	gdb $(TARGET) -ex "$(SUBSTITUTE_ROOT)" -ex "gef-remote --qemu-user localhost 1234" -ex "break _start"


# ────────────────────────────────
# raspberry pi
# .

pi-kernel:
	sudo qemu-system-aarch64 -enable-kvm \
		-m 2G \
		-machine virt,accel=kvm,gic-version=host -cpu host -nographic \
		-kernel $(TARGET) \
		-d int -D qemu.log \
		| tee kernel.log

pi-compare:
	sudo qemu-system-aarch64 -enable-kvm \
		-m 2G \
		-machine virt,accel=kvm,gic-version=host -cpu host -nographic \
		-kernel $(TARGET)

	@echo ""
	@echo "[QEMU] done!"
	@echo "---- ---- ---- ---- ---- ---- ---- ----"
	@echo ""
	@./c63enc
	@echo "[ENCODER] done!"
	@echo "---- ---- ---- ---- ---- ---- ---- ----"


pi-debug:
	sudo qemu-system-aarch64 \
		-m 2G \
		-machine virt,accel=kvm,gic-version=host -cpu host -nographic \
		-kernel $(TARGET) \
		-s -S

pi-gef-attatch:
	gdb $(TARGET) -ex "$(SUBSTITUTE_ROOT)" -ex "gef-remote --qemu-user 10.42.0.133 1234" -ex "break _start"

# ────────────────────────────────
# piped in/out
# .

INPUT_FILE  := ../videos-yuv/foreman.yuv
OUTPUT_FILE := output.out

pipe-service:
	@mkfifo vmvideo.in
	@mkfifo vmvideo.out

	@qemu-system-aarch64 \
		-m 2G \
		-cpu $(CPU_FLAGS) \
		-machine $(MACHINE_FLAGS) \
		-nographic \
		-kernel $(TARGET) \
		-serial mon:stdio \
		-serial pipe:vmvideo

	@rm vmvideo.in
	@rm vmvideo.out


INPUT_FILE_PI := /tmp/videos-yuv/tractor.yuv
OUTPUT_FILE_PI := /tmp/videos-yuv/output.out

pi-pipe-service:
	@mkfifo vmvideo.in
	@mkfifo vmvideo.out

	sudo qemu-system-aarch64 -enable-kvm \
		-m 3G \
		-cpu host \
		-machine virt,accel=kvm,gic-version=host \
		-nographic \
		-kernel $(TARGET) \
		-serial mon:stdio \
		-serial pipe:vmvideo

	@rm vmvideo.in
	@rm vmvideo.out

pipe-in-out:
	@cat vmvideo.out > $(OUTPUT_FILE_PI) &
	@cat $(INPUT_FILE_PI) EOF > vmvideo.in &

	@echo "[INPUT]  piping $(INPUT_FILE) to vm"
	@echo "[OUTPUT] saved to $(OUTPUT_FILE)"

	@ls -l $(INPUT_FILE_PI) $(OUTPUT_FILE_PI)

pipe-mkfifo:
	@mkfifo vmvideo.in
	@mkfifo vmvideo.out

pipe-clean-fifo:
	@rm vmvideo.in
	@rm vmvideo.out

LOAD_FILE := ../videos-yuv/foreman.yuv
# LOAD_FILE := ../videos-yuv/tractor.yuv

# LOAD_FILE_PI := /tmp/videos-yuv/foreman.yuv
LOAD_FILE_PI := /tmp/videos-yuv/tractor.yuv

2_GB_POS  := 0x80000000

# pmemsave 0x4070b8c0 300 output-x264

load-service:
	@qemu-system-aarch64 \
		-m 3G \
		-cpu $(CPU_FLAGS) \
		-machine $(MACHINE_FLAGS) \
		-kernel $(TARGET) \
		-device loader,file=$(LOAD_FILE),addr=$(2_GB_POS) \
		-nographic

pi-load-service:
	sudo qemu-system-aarch64 \
		-enable-kvm \
		-cpu host \
		-m 4G \
		-machine virt,accel=kvm,gic-version=host \
		-kernel $(TARGET) \
		-device loader,file=$(LOAD_FILE_PI),addr=$(2_GB_POS) \
		-nographic

pi-load-service-linux-vm:
	sudo qemu-system-aarch64 \
		-enable-kvm \
		-cpu host \
		-machine virt,accel=kvm,gic-version=host \
		-m 4G \
		-kernel Image \
		-initrd initramfs.cpio.gz \
		-append "console=ttyAMA0" \
		-drive file=../video.img,if=virtio,format=raw \
		-nographic

linux_vm:
	cp -f ../raspberrypi/linux_vm initramfs
	(cd initramfs && find . -print0 | cpio --null -ov --format=newc | gzip > ../initramfs.cpio.gz)

	qemu-system-aarch64 \
		-machine virt \
		-cpu $(CPU_FLAGS) \
		-m 5G \
		-kernel ../linux/arch/arm64/boot/Image \
		-append "console=ttyAMA0 init=/linux_vm" \
		-initrd initramfs.cpio.gz \
		-device loader,file=../videos-yuv/tractor.yuv,addr=0x80000000 \
		-nographic

# ----------------
# COMPARING
# ----------------

# m_LOAD_FILE_PI := ../videos-yuv/foreman.yuv
m_LOAD_FILE_PI := ../videos-yuv/tractor.yuv
m_2_GB_POS  := 0x80000000

DATE_TOD := 17-03-

run-all-compare:
	sync
	echo 3 | sudo tee /proc/sys/vm/drop_caches
	make run-test-Linux-nat >> ../data-logs/$(DATE_TOD)Linux-NAT

	sync
	echo 3 | sudo tee /proc/sys/vm/drop_caches
	make run-test-IOS >> ../data-logs/$(DATE_TOD)IOS

	sync
	echo 3 | sudo tee /proc/sys/vm/drop_caches
	make run-test-Linux-VM >> ../data-logs/$(DATE_TOD)Linux-VM

run-test-Linux-nat:
	taskset -c 1 ./hello_linux

run-test-IOS:
	sudo taskset -c 1 qemu-system-aarch64 \
		-enable-kvm \
		-smp 1 \
		-m 4G \
		-cpu host \
		-machine virt,accel=kvm,gic-version=host \
		-kernel $(TARGET) \
		-device loader,file=$(m_LOAD_FILE_PI),addr=$(m_2_GB_POS) \
		-nographic

run-test-Linux-VM:
	sudo taskset -c 1 qemu-system-aarch64 \
		-smp 1 \
		-enable-kvm \
		-cpu host \
		-machine virt,accel=kvm,gic-version=host \
		-m 4G \
		-kernel Image \
		-initrd initramfs.cpio.gz \
		-append "console=ttyAMA0" \
		-drive file=../video.img,if=virtio,format=raw \
		-nographic

