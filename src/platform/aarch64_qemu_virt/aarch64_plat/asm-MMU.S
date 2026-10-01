/* ----------------------------------------------------------------------
 * Initialize Memory Management Unit (identity mapping)
 *
 * The MMU must be enabled to allow unaligned memory access
 *
 * When the MMU is disabled:
 * - All data accesses are treated as 'Device'-nGnRnE.
 * - Unaligned access to a 'Device' region triggers an exception (alignment fault).
 * - developer.arm.com/documentation/102376/0200/Alignment-and-endianness/Alignment
 *
 * When the MMU is enabled:
 * - Unaligned accesses are allowed to addresses marked as 'Normal'
 *
 * MMU table:
 * - We use only Level 1 table entries (L1, no L2/L3 tables)
 * - 1 GiB per entry.
 * */


/* ----------------------------------------------------------------------
 * MAIR_EL1:
 *   AttrIdx 0 = Normal, non-cacheable (0b01000100)
 *   AttrIdx 1 = Normal, WB/WA         (0b11111111)
 *   AttrIdx 2 = Device-nGnRnE         (0b00000000)
 * */
.equ MAIR_TABLE, 0x000000000000FF44

.equ ATTRIDX_0,    (0 << 2)
.equ ATTRIDX_1,    (1 << 2)
.equ ATTRIDX_2,    (2 << 2)

/* L1 block descriptors */
.equ DESC_BLOCK,   (1 << 0)
.equ DESC_AF,      (1 << 10)
.equ DESC_PXN,     (1 << 53)
.equ DESC_UXN,     (1 << 54)

.equ INNER_SHARE,  (3 << 8)

/* Normal uncached */
.equ TT_NORMAL_NO_CACHE, \
    (DESC_BLOCK | DESC_AF | INNER_SHARE | ATTRIDX_0)

/* Normal cached WB/WA */
.equ TT_NORMAL_WB, \
    (DESC_BLOCK | DESC_AF | INNER_SHARE | ATTRIDX_1)

/* Device memory */
.equ TT_DEVICE_nGnRnE, \
     (DESC_BLOCK | DESC_AF | ATTRIDX_2 | DESC_PXN | DESC_UXN)


/* --------------------------------------------------------------------------
 * mmu_init_identity
 *
 * Set up a minimal Stage-1 MMU configuration with:
 *  - Identity-mapped, virtual == physical addresses
 *  - 1 GiB L1 block mappings:
 *      [0-1GB] 0x0000_0000 - 0x3FFF_FFFF : Device
 *      [1-2GB] 0x4000_0000 - 0x7FFF_FFFF : Normal, cacheable
 *      [2-3GB] 0x8000_0000 - 0xBFFF_FFFF : Normal, cacheable
 *      [3-4GB] ...etc...
 *
 * */
.global mmu_init_identity
mmu_init_identity:

    /* ----------------------------------------------------------------------
     * Translation table base
     * */
    ldr     x0, =tt_l1_base
    msr     TTBR0_EL1, x0

    /* ----------------------------------------------------------------------
     * Memory attributes (MAIR_EL1)
     * */
    ldr     x0, =MAIR_TABLE
    msr     MAIR_EL1, x0

    /* ----------------------------------------------------------------------
     * Translation control (TCR_EL1) disable TTBR1, no kernel/user split.
     * */
    mov     x0, #0x19             // T0SZ = 39-bit VA, L1 start
    orr     x0, x0, #(1 << 23)    // EPD1 = 1 (disable TTBR1)
    msr     TCR_EL1, x0
    isb

    /* ----------------------------------------------------------------------
     * Invalidate TLBs
     * */
    tlbi    VMALLE1
    dsb     sy
    isb

    /* ----------------------------------------------------------------------
     * Build L1 identity map
     * */
    ldr     x1, =tt_l1_base

    /* [0] Device memory @ 0x00000000, 0-1GB */
    ldr     x0, =TT_DEVICE_nGnRnE
    str     x0, [x1, #0]

    /* [1] Normal memory @ 0x40000000, 1-2GB */
    ldr     x0, =TT_NORMAL_WB
    orr     x0, x0, #0x40000000
    str     x0, [x1, #8]

    /* [2] Normal memory @ 0x80000000, 2-3GB */
    ldr     x0, =TT_NORMAL_WB
    orr     x0, x0, #0x80000000
    str     x0, [x1, #16]

    /* etc. */
    ldr     x0, =TT_NORMAL_WB
    orr     x0, x0, #0xC0000000
    str     x0, [x1, #24]

    ldr     x0, =TT_NORMAL_WB
    orr     x0, x0, #0x100000000
    str     x0, [x1, #32]

    dsb     sy

    /* ----------------------------------------------------------------------
     * Enable MMU + caches
     * */
    mrs     x0, SCTLR_EL1
    orr     x0, x0, #(1 << 0)     // M  - MMU enable
    orr     x0, x0, #(1 << 2)     // C  - data cache
    orr     x0, x0, #(1 << 12)    // I  - instruction cache
    msr     SCTLR_EL1, x0
    isb

    ret

/* --------------------------------------------------------------------------
 * Translation table storage
 * */

/* 2^12 = 4096 */
.align 12
.global tt_l1_base
tt_l1_base:
    .fill 4096, 1, 0
