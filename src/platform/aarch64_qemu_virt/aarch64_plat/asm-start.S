/* asm-start.S
 *
 * AArch64 boot entry for IncludeOS (QEMU virt)
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
.extern kernel_start

/* -------------------------------------------------------------------------- */

.global _start
_start:
    /* ----------------------------------------------------------------------
     * Identify CPU
     * -------------------------------------------------------------------- */
    mrs     x0, MPIDR_EL1
    and     x0, x0, #0xff       // Affinity level 0, Aff0: core ID
    cmp     x0, #0              // If affinity is zero: primary core
    b.eq    primary
    b       secondary_core

primary:

    /* ----------------------------------------------------------------------
     * Ensure we are running in EL1
     * -------------------------------------------------------------------- */
    mrs     x0, CurrentEL
    lsr     x0, x0, #2
    cmp     x0, #1
    b.ne    .                   // For now: hang if not EL1

    /* ----------------------------------------------------------------------
     * Mask all interrupts
     * -------------------------------------------------------------------- */
    msr     DAIFSet, #0b1111

    /* ----------------------------------------------------------------------
     * Install exception vector table
     * -------------------------------------------------------------------- */
    bl      install_exception_vector_EL1

    /* ----------------------------------------------------------------------
     * Enable FP / SIMD (NEON)
     * -------------------------------------------------------------------- */
    mrs     x0, CPACR_EL1
    orr     x0, x0, #(3 << 20)   // FPEN = 0b11 (full access)
    msr     CPACR_EL1, x0
    isb

    /* Reset FP state */
    msr     FPCR, xzr
    msr     FPSR, xzr
    isb

    /* ----------------------------------------------------------------------
     * Initialize Memory Management Unit (identity mapping)
     *
     * The MMU must be enabled to allow unaligned memory access
     *
     * When the MMU is disabled:
     * - All data accesses are treated as Device-nGnRnE.
     * - Unaligned access to a Device region triggers an exception (alignment fault).
     * - developer.arm.com/documentation/102376/0200/Alignment-and-endianness/Alignment
     *
     * When the MMU is enabled:
     * - Unaligned accesses are allowed to addresses marked as 'Normal'
     *
     * -------------------------------------------------------------------- */
    bl      mmu_init_identity

    /* ----------------------------------------------------------------------
     * Set up stack
     * -------------------------------------------------------------------- */
    ldr     x0, =__stack_top
    mov     sp, x0

    /* ----------------------------------------------------------------------
     * Detour into misc functions
     * -------------------------------------------------------------------- */
    mov      x0, xzr
    bl      info_kernel_main
    bl      info_FP_SIMD
    bl      info_mmu

    /* ----------------------------------------------------------------------
     * Set up the Generic Interrupt Controller
     * -------------------------------------------------------------------- */
    bl      gicv3_init

    /* ----------------------------------------------------------------------
     * Jump to kernel
     * -------------------------------------------------------------------- */
    bl      kernel_start

halt:
    wfe
    b       halt

/* --------------------------------------------------------------------------
 * Secondary cores
 * -------------------------------------------------------------------------- */

secondary_core:
    wfi
    b       secondary_core

/* --------------------------------------------------------------------------
 * MMU descriptor templates (L1 block entries)
 * --------------------------------------------------------------------------
 *
 * We use only L1 block entries (1 GiB per entry).
 * No L2/L3 tables.
 */

/* MAIR_EL1:
 *   AttrIdx 0 = Normal, non-cacheable (0b01000100)
 *   AttrIdx 1 = Normal, WB/WA         (0b11111111)
 *   AttrIdx 2 = Device-nGnRnE         (0b00000000)
 */
.equ MAIR_TABLE, 0x000000000000FF44

.equ ATTRIDX_0,    (0 << 2)
.equ ATTRIDX_1,    (0 << 1)
.equ ATTRIDX_2,    (2 << 2)

/* L1 block descriptors */
.equ DESC_BLOCK,   (1 << 0)
.equ DESC_AF,      (1 << 10)
.equ DESC_PXN,     (1 << 53)
.equ DESC_UXN,     (1 << 54)

/* AF=1, AttrIdx=0 */
.equ TT_NORMAL_NO_CACHE, \
     (DESC_BLOCK | DESC_AF | ATTRIDX_0)

/* AF=1, AttrIdx=2, PXN=UXN=1 */
.equ TT_DEVICE_nGnRnE, \
     (DESC_BLOCK | DESC_AF | ATTRIDX_2 | DESC_PXN | DESC_UXN)


/* --------------------------------------------------------------------------
 * MMU initialization
 * -------------------------------------------------------------------------- */

/*
 * mmu_init_identity
 *
 * Sets up a minimal Stage-1 MMU configuration with:
 *  - Identity-mapped virtual == physical addresses
 *  - 1 GiB L1 block mappings:
 *      [0] 0x0000_0000 - 0x3FFF_FFFF : Device
 *      [1] 0x4000_0000 - 0x7FFF_FFFF : Normal, non-cacheable
 *      [2] 0x8000_0000 - 0xBFFF_FFFF : Normal, non-cacheable
 *      ...
 *
 * TTBR1 disabled
 * No higher-half, no kernel/user split
 */
.global mmu_init_identity
mmu_init_identity:

    /* ----------------------------------------------------------------------
     * Translation table base
     * -------------------------------------------------------------------- */
    ldr     x0, =tt_l1_base
    msr     TTBR0_EL1, x0

    /* ----------------------------------------------------------------------
     * Memory attributes (MAIR_EL1)
     * -------------------------------------------------------------------- */
    ldr     x0, =MAIR_TABLE
    msr     MAIR_EL1, x0

    /* ----------------------------------------------------------------------
     * Translation control (TCR_EL1)
     * -------------------------------------------------------------------- */
    mov     x0, #0x19             // T0SZ = 39-bit VA, L1 start
    orr     x0, x0, #(1 << 23)    // EPD1 = 1 (disable TTBR1)
    msr     TCR_EL1, x0
    isb

    /* ----------------------------------------------------------------------
     * Invalidate TLBs
     * -------------------------------------------------------------------- */
    tlbi    VMALLE1
    dsb     sy
    isb

    /* ----------------------------------------------------------------------
     * Build L1 identity map
     * -------------------------------------------------------------------- */
    ldr     x1, =tt_l1_base

    /* [0] Device memory @ 0x00000000 */
    ldr     x0, =TT_DEVICE_nGnRnE
    str     x0, [x1, #0]

    /* [1] Normal memory @ 0x40000000 */
    ldr     x0, =TT_NORMAL_NO_CACHE
    orr     x0, x0, #0x40000000
    str     x0, [x1, #8]

    /* [2] Normal memory @ 0x80000000 */
    ldr     x0, =TT_NORMAL_NO_CACHE
    orr     x0, x0, #0x80000000
    str     x0, [x1, #16]

    dsb     sy

    /* ----------------------------------------------------------------------
     * Enable MMU + caches
     * -------------------------------------------------------------------- */
    mrs     x0, SCTLR_EL1
    orr     x0, x0, #(1 << 0)     // M  - MMU enable
    orr     x0, x0, #(1 << 2)     // C  - data cache
    orr     x0, x0, #(1 << 12)    // I  - instruction cache
    msr     SCTLR_EL1, x0
    isb

    ret

/* --------------------------------------------------------------------------
 * Translation table storage
 * -------------------------------------------------------------------------- */

/* 2^12 = 4096 */
.align 12
.global tt_l1_base
tt_l1_base:
    .fill 4096, 1, 0
