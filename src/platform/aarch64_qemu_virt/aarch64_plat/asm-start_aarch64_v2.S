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
    nop                  /* u32 code0;       Executable code      */
    b     reset          /* u32 code1;       Executable code      */
                         /*                  .                    */
    .quad 0              /* u64 text_offset; Image load offset    */
                         /*                  .                    */
    .quad _end - _start  /* u64 image_size;  Effective Image size */
                         /*                  .                    */
    .quad 0b1010         /* u64 flags;       kernel flags         */
                         /*                  .                    */
    .quad 0              /* u64 res2;        reserved             */
    .quad 0              /* u64 res3;        reserved             */
    .quad 0              /* u64 res4;        reserved             */
                         /*                  .                    */
    .ascii "ARM\x64"     /* u32 magic;       "ARM\x64"            */
                         /*                  .                    */
    .byte 0, 0, 0, 0     /* u32 res5;        reserved             */


reset:
    // --- save x0
    mov     x9, x0

    // --- Enable FP/SIMD (NEON) for EL0/EL1
    mrs     x0, CPACR_EL1               // read CPACR_EL1
    orr     x0, x0, #(0x3 << 20)        // set FPEN[21:20] = 0b11 (full access)
    msr     CPACR_EL1, x0               // write back
    isb                                 // MUST follow write to CPACR_EL1

    // --- Set FP control/status to known state (zero)
    msr     FPCR, xZR
    msr     FPSR, xZR
    isb

    // --- usual boot (stack, jump to kernel, etc.)
    ldr     x8, =__stack_top
    mov     sp, x8
    mov     x0, x9

    // --- detour into debug functions
    bl      info_kernel_main
    bl      info_mmu
    bl      info_FP_SIMD

    // --- jump to kernel
    bl      kernel_start

loop:
    wfe
    b loop
