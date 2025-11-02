/*
* traps_aarch64.S
* Exception vector table and entry stubs for IncludeOS AArch64
*
* Compatible with EL1 kernels (running under QEMU virt)
*/

.section .text.exceptions
.align 11                        // 2KB alignment required; 2^11 = 2048
.global exception_vector

// --- Vector table layout ----------------------------------------
exception_vector:
    // 0x000 - Synchronous from current EL using SP_EL0
    b   sync_current_el_sp0
    .org exception_vector + 0x80
    b   irq_current_el_sp0
    .org exception_vector + 0x100
    b   fiq_current_el_sp0
    .org exception_vector + 0x180
    b   serr_current_el_sp0

    // 0x200 - Synchronous from current EL using SP_EL1
    .org exception_vector + 0x200
    b   sync_current_el_spx
    .org exception_vector + 0x280
    b   irq_current_el_spx
    .org exception_vector + 0x300
    b   fiq_current_el_spx
    .org exception_vector + 0x380
    b   serr_current_el_spx

    // 0x400 - Synchronous from lower EL (AArch64)
    .org exception_vector + 0x400
    b   sync_lower_el_aarch64
    .org exception_vector + 0x480
    b   irq_lower_el_aarch64
    .org exception_vector + 0x500
    b   fiq_lower_el_aarch64
    .org exception_vector + 0x580
    b   serr_lower_el_aarch64

    // 0x600 - Synchronous from lower EL (AArch32)
    .org exception_vector + 0x600
    b   sync_lower_el_aarch32
    .org exception_vector + 0x680
    b   irq_lower_el_aarch32
    .org exception_vector + 0x700
    b   fiq_lower_el_aarch32
    .org exception_vector + 0x780
    b   serr_lower_el_aarch32

    //-------------------------------------------------------------------
    // Generic handler stubs
    //-------------------------------------------------------------------

    .macro SAVE_REGS
    sub sp, sp, #(16*5)
    stp x0, x1, [sp, #(16*0)]
    stp x2, x3, [sp, #(16*1)]
    stp x4, x5, [sp, #(16*2)]
    stp x6, x7, [sp, #(16*3)]
    stp x8, x9, [sp, #(16*4)]
    .endm

    .macro RESTORE_REGS
    ldp x8, x9, [sp, #(16*4)]
    ldp x6, x7, [sp, #(16*3)]
    ldp x4, x5, [sp, #(16*2)]
    ldp x2, x3, [sp, #(16*1)]
    ldp x0, x1, [sp, #(16*0)]
    add sp, sp, #(16*5)
    .endm

    .macro EXCEPTION_ENTRY type
    SAVE_REGS
    mrs x1, ESR_EL1
    mrs x2, FAR_EL1
    mrs x3, SPSR_EL1
    mrs x4, ELR_EL1
    mov x0, \type
    bl  exception_entry           // call C handler
    RESTORE_REGS
    eret
    .endm

//--- handlers for each exception type -------------------------------
sync_current_el_sp0:       EXCEPTION_ENTRY 0
irq_current_el_sp0:        EXCEPTION_ENTRY 1
fiq_current_el_sp0:        EXCEPTION_ENTRY 2
serr_current_el_sp0:       EXCEPTION_ENTRY 3

sync_current_el_spx:       EXCEPTION_ENTRY 4
irq_current_el_spx:        EXCEPTION_ENTRY 5
fiq_current_el_spx:        EXCEPTION_ENTRY 6
serr_current_el_spx:       EXCEPTION_ENTRY 7

sync_lower_el_aarch64:     EXCEPTION_ENTRY 8
irq_lower_el_aarch64:      EXCEPTION_ENTRY 9
fiq_lower_el_aarch64:      EXCEPTION_ENTRY 10
serr_lower_el_aarch64:     EXCEPTION_ENTRY 11

sync_lower_el_aarch32:     EXCEPTION_ENTRY 12
irq_lower_el_aarch32:      EXCEPTION_ENTRY 13
fiq_lower_el_aarch32:      EXCEPTION_ENTRY 14
serr_lower_el_aarch32:     EXCEPTION_ENTRY 15
