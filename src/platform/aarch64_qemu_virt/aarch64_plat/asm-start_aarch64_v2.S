#include <macros.h>

.section .text
.global _start
.global reset
.global init_serial

.extern _end
.extern __stack_top
.extern __boot_magic
.extern exception_vector

_start:
    // code0/code1
    nop
    b reset

    // text_offset
    .quad 0

    // image_size
    .quad _end - _start

    // flags
    .quad 0b1010

    // Reserved fields
    .quad 0
    .quad 0
    .quad 0

    // magic - yes 0x644d5241 is the same as ASCII string "ARM\x64"
    .ascii "ARM\x64"

    // Another reserved field at the end of the header
    .byte 0, 0, 0, 0

reset:
    // --- Enable FP/SIMD (NEON) for EL0/EL1 ---
    mrs     x0, CPACR_EL1               // read CPACR_EL1
    orr     x0, x0, #(0x3 << 20)        // set FPEN[21:20] = 0b11 (full access)
    msr     CPACR_EL1, x0               // write back
    isb                                 // MUST follow write to CPACR_EL1

    // --- Init FP control/status to known state (optional but recommended) ---
    mov     x0, #0
    msr     FPCR, x0
    msr     FPSR, x0
    isb                                 // not strictly required here, harmless

    // --- usual boot (stack, jump to kernel) ---
    ldr     x8, =__stack_top
    mov     sp, x8
    bl      kernel_start
    b       .
loop:
    b loop
