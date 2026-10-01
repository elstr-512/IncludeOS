/* ----------------------------------------------------------------------
 * AArch64 boot for IncludeOS
 *
 * Responsibilities:
 *  - Select primary CPU
 *  - Initialize EL1 state
 *  - Install exception vectors
 *  - Enable FP/SIMD
 *  - Set up a minimal identity-mapped MMU
 *  - Set stack and jump into C++ kernel
 */

.section .text.boot
.align  7

.extern __stack_top

.extern exception_vector
.extern mmu_init_identity
.extern kernel_start

.global _start
_start:
    /* ----------------------------------------------------------------------
     * Identify CPU
     * */
    mrs     x0, MPIDR_EL1
    and     x0, x0, #0xff       // Affinity level 0, Aff0: core ID
    cmp     x0, #0              // If affinity is zero: primary core
    b.eq    primary
    b       secondary_core

primary:
    /* ----------------------------------------------------------------------
     * Ensure we are running in EL1
     * */
    mrs     x0, CurrentEL
    lsr     x0, x0, #2
    cmp     x0, #1
    b.ne    .   // For now: hang if not EL1

    /* ----------------------------------------------------------------------
     * Mask all interrupts
     * */
    msr     DAIFSet, #0b1111

    /* ----------------------------------------------------------------------
     * Install exception vector table
     * */
    bl      install_exception_vector_EL1

    /* ----------------------------------------------------------------------
     * Enable FP / SIMD (NEON)
     * */
    mrs     x0, CPACR_EL1
    orr     x0, x0, #(3 << 20)   // FPEN = 0b11 (full access)
    msr     CPACR_EL1, x0
    isb

    /* Reset FP state */
    msr     FPCR, xzr
    msr     FPSR, xzr
    isb

    /* ----------------------------------------------------------------------
     * Initialize Memory Management Unit
     * */
    bl      mmu_init_identity

    /* ----------------------------------------------------------------------
     * Set up stack
     * */
    ldr     x0, =__stack_top
    mov     sp, x0

    /* ----------------------------------------------------------------------
     * Detour into misc/test functions
     * */
    mov      x0, xzr
    bl      info_kernel_main
    bl      info_FP_SIMD
    bl      info_mmu

    /* ----------------------------------------------------------------------
     * Set up the Generic Interrupt Controller
     * */
     bl      gicv3_init

    /* ----------------------------------------------------------------------
     * Jump to kernel
     * */
    bl      kernel_start

halt:
    wfe
    b       halt

secondary_core:
    wfe
    b       secondary_core

