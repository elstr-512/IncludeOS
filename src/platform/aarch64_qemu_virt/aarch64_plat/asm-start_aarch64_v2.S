//==================================================================
// The Memory Management Unit needs to be enabled in order
// to allow unaligned memory access
//
// When the stage 1 MMU is disabled:
//
// All data accesses are Device-nGnRnE.
//
// developer.arm.com/documentation/102376/0200/Alignment-and-endianness/Alignment
//
// Unaligned accesses are allowed to addresses marked as Normal, but not to Device
// regions. An unaligned access to a Device region will trigger an exception
// (alignment fault).
//
// Armv8-A example - Minimal EL1 MMU set up example
// developer.arm.com/documentation/102416/0100/EL1-Single-level-table
//
// Copyright (C) Arm Limited, 2019 All rights reserved.
//==================================================================

.section .text.boot

  .align 3

// ------------------------------------------------------------

.equ Mode_USR, 0x10

.equ AArch32_Mode_USR,     0x10
.equ AArch32_Mode_FIQ,     0x11
.equ AArch32_Mode_IRQ,     0x12
.equ AArch32_Mode_SVC,     0x13
.equ AArch32_Mode_ABT,     0x17
.equ AArch32_Mode_UNDEF,   0x1B
.equ AArch32_Mode_SYS,     0x1F
.equ AArch32_Mode_HYP,     0x1A
.equ AArch32_Mode_MON,     0x16

.equ AArch64_EL2_SP2,      0x09    // EL2h
.equ AArch64_EL2_SP0,      0x08    // EL2t
.equ AArch64_EL1_SP1,      0x05    // EL1h
.equ AArch64_EL1_SP0,      0x04    // EL1t
.equ AArch64_EL0_SP0,      0x00

.equ AArch32_State_Thumb,  0x20
.equ AArch32_State_ARM,    0x00

// ------------------------------------------------------------

.equ TT_S1_TABLE,          0x00000000000000003    // NSTable=0, PXNTable=0, UXNTable=0, APTable=0

// TT block entries templates   (L1 and L2, NOT L3)
// Assuming table contents:
// 0 = b01000100 = Normal, Inner/Outer Non-Cacheable
// 1 = b11111111 = Normal, Inner/Outer WB/WA/RA
// 2 = b00000000 = Device-nGnRnE
.equ TT_S1_FAULT,           0x0
.equ TT_S1_NORMAL_NO_CACHE, 0x00000000000000401    // Index = 0, AF=1
.equ TT_S1_NORMAL_WBWA,     0x00000000000000405    // Index = 1, AF=1
.equ TT_S1_DEVICE_nGnRnE,   0x00600000000000409    // Index = 2, AF=1, PXN=1, UXN=1

.equ TT_S1_UXN,             (1 << 54)
.equ TT_S1_PXN,             (1 << 53)
.equ TT_S1_nG,              (1 << 11)
.equ TT_S1_NS,              (1 << 5)

.equ TT_S1_NON_SHARED,      (0 << 8)               // Non-shareable
.equ TT_S1_INNER_SHARED,    (3 << 8)               // Inner-shareable
.equ TT_S1_OUTER_SHARED,    (2 << 8)               // Outer-shareable

.equ TT_S1_PRIV_RW,         (0x0)
.equ TT_S1_PRIV_RO,         (0x2 << 6)
.equ TT_S1_USER_RW,         (0x1 << 6)
.equ TT_S1_USER_RO,         (0x3 << 6)

.equ TT_S1_DBM,             (0x1 << 51)

// ------------------------------------------------------------

  .global _start
  .type _start, @function
_start:

  // Clear registers
  // ---------------
  // This is primarily for RTL simulators, to avoid
  // possibility of X propergation
  MOV      x0, #0
  MOV      x1, #0
  MOV      x2, #0
  MOV      x3, #0
  MOV      x4, #0
  MOV      x5, #0
  MOV      x6, #0
  MOV      x7, #0
  MOV      x8, #0
  MOV      x9, #0
  MOV      x10, #0
  MOV      x11, #0
  MOV      x12, #0
  MOV      x13, #0
  MOV      x14, #0
  MOV      x15, #0
  MOV      x16, #0
  MOV      x17, #0
  MOV      x18, #0
  MOV      x19, #0
  MOV      x20, #0
  MOV      x21, #0
  MOV      x22, #0
  MOV      x23, #0
  MOV      x24, #0
  MOV      x25, #0
  MOV      x26, #0
  MOV      x27, #0
  MOV      x28, #0
  MOV      x29, #0
  MOV      x30, #0

  // Which core am I
  // ----------------
  MRS      x0, MPIDR_EL1
  AND      x0, x0, #0xFF                     // Mask off to leave Aff0
  CBZ      x0, primary                       // If core 0, run the primary init
  B        secondary                         // Else, run secondary init

// ------------------------------------------------------------
// Primary core
// ------------------------------------------------------------

primary:

  // Get current Exception Level, EL, bits [3:2]
  // -------------------------------------------------------------
    MRS x0, CurrentEL
    LSR x0, x0, #2

    CMP x0, #3
    B.eq primary_EL3

    CMP x0, #2
    B.eq primary_EL2

    CMP x0, #1
    B.eq primary_EL1

primary_EL3:
    // Enter EL3, not doing much atm
    LDR      x0, =exception_vector
    MSR      VBAR_EL3, x0

primary_EL2:
    // Enter EL2, not doing much atm
    LDR      x0, =exception_vector
    MSR      VBAR_EL2, x0

primary_EL1:
    // Enter EL1
    // ---------------------

    // Install exception vector table
    // ---------------------
    LDR      x0, =exception_vector
    MSR      VBAR_EL1, x0
    isb

    // Enable FP/SIMD/NEON
    // ---------------------
    mrs     x0, CPACR_EL1
    orr     x0, x0, #(0x3 << 20)        // set FPEN[21:20] = 0b11 (full access)
    msr     CPACR_EL1, x0
    isb

    // Set FP control/status to known state (zero)
    // ---------------------
    msr     FPCR, xZR
    msr     FPSR, xZR
    isb

    // Set SCTLRs for EL1 to safe values
    // ---------------------
    // MSR     SCTLR_EL1, xzr

    // MMU setup
    // ---------------------

    // Set the Base address
    // ---------------------
    LDR      x0, =tt_l1_base                  // Get address of level 1 for TTBR0_EL1
    MSR      TTBR0_EL1, x0


    // Set up memory attributes
    // -------------------------
    // This equates to:
    // 0 = b01000100 = Normal, Inner/Outer Non-Cacheable
    // 1 = b11111111 = Normal, Inner/Outer WB/WA/RA
    // 2 = b00000000 = Device-nGnRnE
    MOV      x0, #0x000000000000FF44
    MSR      MAIR_EL1, x0


    // Set up TCR_EL1
    // ---------------
    MOV      x0, #0x19                  // T0SZ=0b011001 Limits VA space to 39 bits,
                                        // translation starts @ l1
    ORR      x0, x0, #(0x1 << 8)        // IGRN0=0b01    Walks to TTBR0 are Inner WB/WA
    ORR      x0, x0, #(0x1 << 10)       // OGRN0=0b01    Walks to TTBR0 are Outer WB/WA
    ORR      x0, x0, #(0x3 << 12)       // SH0=0b11      Inner Shareable
    ORR      x0, x0, #(0x1 << 23)       // EPD1=0b1      Disable table walks from TTBR1
                                        // TBI0=0b0
                                        // TG0=0b00      4KB granule for TTBR0
                                        // (Note: Different encoding to TG0)
                                        // A1=0          TTBR0 contains the ASID
                                        // AS=0          8-bit ASID
                                        // IPS=0         32-bit IPA space
    MSR      TCR_EL1, x0

    // NOTE: We don't need to set up T1SZ/TBI1/ORGN1/IRGN1/SH1,
    // as we've set EPD==1 (disabling walks from TTBR1)

    // Ensure changes to system register are visible before MMU enabled
    ISB


    // Invalidate TLBs
    // ----------------
    TLBI     VMALLE1
    DSB      SY
    ISB


    // Generate Translation Table
    // Very basic translation table
    // ---------------------------
    //
    LDR      x1, =tt_l1_base                // Address of L1 table

    // [0]: 0x0000,0000 - 0x3FFF,FFFF
    LDR      x0, =TT_S1_DEVICE_nGnRnE       // Entry template
                                            // Don't need to OR in address, as it is 0
                                            // AP=0b00, EL1 RW, EL0 No Access
    STR      x0, [x1]

    // [1]: 0x4000,0000 - 0x7FFF,FFFF
    LDR      x0, =TT_S1_NORMAL_NO_CACHE     // Entry template
    ORR      x0, x0, #0x40000000            // 'OR' template with base physical address
                                            // AP=0b00, EL1 RW, EL0 No Access
    STR      x0, [x1, #8]

    // [2]: 0x8000,0000 - 0xBFFF,FFFF (DRAM on the VE and Base Platform)
    LDR      x0, =TT_S1_NORMAL_WBWA         // Entry template
    ORR      x0, x0, #TT_S1_INNER_SHARED    // 'OR' with inner-shareable attribute
    ORR      x0, x0, #0x80000000            // 'OR' template with base physical address
                                            // AP=0b00, EL1 RW, EL0 No Access
    STR      x0, [x1, #16]

    DSB      SY


    // Enable MMU
    // -----------
    // M=1      b[0]    Enable the stage 1 MMU
    // A=0      b[1]    Strict alignment checking disabled
    // C=1      b[2]    Enable data and unified caches
    // SA=0     b[4]    Stack alignment checking disabled
    // I=1      b[12]   Enable instruction fetches to allocate into unified caches
    // WXN=0    b[20]   Write permission does not imply XN
    // EE=0     b[26]   EL3 data accesses are little endian

    MOV      x0, #(1 << 0)
    ORR      x0, x0, #(1 << 2)
    ORR      x0, x0, #(1 << 12)

    MSR      SCTLR_EL1, x0
    ISB

    // MMU is now enabled
    // -----------

    NOP
    NOP
    NOP
    NOP

    // usual boot (stack, jump to kernel, etc.)
    // -----------
    ldr     x8, =__stack_top
    mov     sp, x8

    // detour into some info routines
    // -----------
    mov      x0, #0
    bl      info_kernel_main
    bl      info_FP_SIMD
    bl      info_mmu

    // jump to kernel
    // -----------
    bl      kernel_start

loop:
    wfe
    b loop

// ------------------------------------------------------------
// Secondary cores
// ------------------------------------------------------------
secondary:
    wfi
    b        secondary

signal_qemu_stop:
    // qemu-system-aarch64 virt PSCI SYSTEM_OFF (function ID 0x84000008)
    // Hypervisor call -> power off
    // -----------
    ldr x0, =0x84000008
    hvc     #0

// ------------------------------------------------------------
// MMU Translation tables
// ------------------------------------------------------------

.align 12 // 2^12 = 4096
.global tt_l1_base
tt_l1_base:
    .fill 4096 , 1 , 0

