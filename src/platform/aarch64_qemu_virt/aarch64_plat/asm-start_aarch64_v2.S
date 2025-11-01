#include <macros.h>

.section .text.boot
.global _start
.global reset
.global init_serial

.extern _end
.extern __stack_top
.extern __boot_magic
.extern exception_vector
.extern kernel_start

/*
 * NOTE: _start is the Linux image header
 * https://docs.kernel.org/arch/arm64/booting.html
**/

_start:
    // [Executable code] u32 code0;
    // [Executable code] u32 code1;
    nop
    b reset

    // [Image load offset, little endian] u64 text_offset;
    .quad 0

    // [Effective Image size, little endian] u64 image_size;
    .quad _end - _start

    // [kernel flags, little endian] u64 flags;
    .quad 0b1010

    // [reserved] u64 res2 = 0;
    // [reserved] u64 res3 = 0;
    // [reserved] u64 res4 = 0;
    .quad 0
    .quad 0
    .quad 0

    // [Magic number, little endian, "ARM\x64"] u32 magic = 0x644d5241;
    .ascii "ARM\x64"

    // [reserved (used for PE COFF offset)] u32 res5;
    .byte 0, 0, 0, 0

reset:
    // --- Enable FP/SIMD (NEON) for EL0/EL1
    mrs     x0, CPACR_EL1               // read CPACR_EL1
    orr     x0, x0, #(0x3 << 20)        // set FPEN[21:20] = 0b11 (full access)
    msr     CPACR_EL1, x0               // write back
    isb                                 // MUST follow write to CPACR_EL1

    // --- Set FP control/status to known state (zero)
    msr     FPCR, xZR
    msr     FPSR, xZR
    isb

    // --- usual boot (stack, jump to kernel)
    ldr     x8, =__stack_top
    mov     sp, x8
    bl      kernel_start

loop:
    wfe
    b loop
