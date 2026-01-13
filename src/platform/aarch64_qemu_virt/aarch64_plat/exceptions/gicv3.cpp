/*
 * gicv3.cpp
 *
 * Minimal GICv3 + ARM generic timer bring-up
 * for QEMU 'virt', gic-version=3, EL1 non-secure.
 *
 * CPU0 only, no SMP support yet.
 *
 * NOTE: Assumptions:
 *  - GIC DISTRIBUTOR          = 0x08000000
 *  - GIC REDISTRIBUTOR (CPU0) = 0x080a0000
 *
 * TODO:
 *  - Discover GIC addresses from Device Tree
 *  - SMP
 */

extern "C" {

#include <cstdint>
#include <kprint>
#include "gicv3.hpp"
#include "../info/info_uart_print.hpp"

/* ----------------------------------------------------------
 * Debug
 * ---------------------------------------------------------- */

#define GIC_LOG_DEF 1
#if GIC_LOG_DEF
#define GIC_LOG(fmt, ...) kprintf("[GICv3] %s", fmt, ##__VA_ARGS__)
#else
#define GIC_LOG(fmt, ...)
#endif

/* ----------------------------------------------------------
 * MMIO helpers
 * ---------------------------------------------------------- */

static inline void mmio_write32(uintptr_t addr, uint32_t v) {
  *reinterpret_cast<volatile uint32_t*>(addr) = v;
}

static inline uint32_t mmio_read32(uintptr_t addr) {
  return *reinterpret_cast<volatile uint32_t*>(addr);
}

static inline void mmio_write32(uintptr_t base, uintptr_t off, uint32_t v) {
  mmio_write32(base + off, v);
}

static inline uint32_t mmio_read32(uintptr_t base, uintptr_t off) {
  return mmio_read32(base + off);
}

/* ----------------------------------------------------------
 * GIC base addresses (QEMU virt, fixed)
 * ---------------------------------------------------------- */

static constexpr uintptr_t GICD_BASE = 0x08000000;
static constexpr uintptr_t GICR_BASE = 0x080A0000;   // CPU0 redistributor

/* ----------------------------------------------------------
 * GIC Distributor
 * ---------------------------------------------------------- */

namespace gicd {

static constexpr uintptr_t CTLR = 0x0000;

/* Enable Group 1 Non-secure interrupts */
static constexpr uint32_t CTLR_ENABLE_G1NS = (1u << 1);

static inline void init(uintptr_t base) {
  mmio_write32(base, CTLR, CTLR_ENABLE_G1NS);
  asm volatile("dsb sy" ::: "memory");
}

} // namespace gicd

/* ----------------------------------------------------------
 * GIC Redistributor (CPU0 only)
 * ---------------------------------------------------------- */

namespace gicr {

static constexpr uintptr_t WAKER          = 0x0014;
static constexpr uintptr_t SGI_BASE       = 0x10000;
static constexpr uintptr_t ISENABLER0     = SGI_BASE + 0x100;
static constexpr uintptr_t IGROUPR0       = SGI_BASE + 0x080;

/* WAKER bits */
static constexpr uint32_t WAKER_PS        = (1u << 1);
static constexpr uint32_t WAKER_CA        = (1u << 2);

static inline void wake(uintptr_t base) {
  uint32_t w = mmio_read32(base, WAKER);
  w &= ~WAKER_PS;                 // clear ProcessorSleep
  mmio_write32(base, WAKER, w);

  /* Wait until ChildrenAsleep == 0 */
  while (mmio_read32(base, WAKER) & WAKER_CA) {
    /* spin */
  }
}

static inline void enable_ppi(uintptr_t base, unsigned irq) {
  uintptr_t reg = base + ISENABLER0;
  uint32_t bit  = 1u << (irq & 31);
  mmio_write32(reg, mmio_read32(reg) | bit);
  asm volatile("dsb sy" ::: "memory");
}

static inline void set_group1(uintptr_t base, unsigned irq) {
  uintptr_t reg = base + IGROUPR0;
  uint32_t bit  = 1u << (irq & 31);
  mmio_write32(reg, mmio_read32(reg) | bit);
  asm volatile("dsb sy" ::: "memory");
}

} // namespace gicr

/* ----------------------------------------------------------
 * CPU interface (ICC_* system registers)
 * ---------------------------------------------------------- */

namespace icc {

static inline void write_sre_el1(uint64_t v) {
  asm volatile("msr ICC_SRE_EL1, %0" :: "r"(v));
}

static inline void write_pmr_el1(uint64_t v) {
  asm volatile("msr ICC_PMR_EL1, %0" :: "r"(v));
}

static inline void write_igrpen1_el1(uint64_t v) {
  asm volatile("msr ICC_IGRPEN1_EL1, %0" :: "r"(v));
}

static inline uint64_t read_iar1_el1(void) {
  uint64_t v;
  asm volatile("mrs %0, ICC_IAR1_EL1" : "=r"(v));
  return v;
}

static inline void write_eoir1_el1(uint64_t v) {
  asm volatile("msr ICC_EOIR1_EL1, %0" :: "r"(v));
}

static inline void enable_sysregs(void) {
  write_sre_el1(1);
  asm volatile("isb" ::: "memory");
}

static inline void set_priority_mask(uint8_t pri = 0xFF) {
  write_pmr_el1(pri);
  asm volatile("isb" ::: "memory");
}

static inline void enable_group1(void) {
  write_igrpen1_el1(1);
  asm volatile("isb" ::: "memory");
}

} // namespace icc

/* ----------------------------------------------------------
 * DAIF helpers
 * ---------------------------------------------------------- */

static inline void daif_mask_all(void) {
  asm volatile("msr daifset, #0xf" ::: "memory");
}

static inline void daif_unmask_irq(void) {
  asm volatile("msr daifclr, #0x2" ::: "memory");
}

/* ----------------------------------------------------------
 * ARM Generic Timer (physical timer)
 * ---------------------------------------------------------- */

namespace timer {

static inline uint64_t cntfrq(void) {
  uint64_t v;
  asm volatile("mrs %0, cntfrq_el0" : "=r"(v));
  return v;
}

static inline uint64_t cntpct(void) {
  uint64_t v;
  asm volatile("mrs %0, cntpct_el0" : "=r"(v));
  return v;
}

static inline void write_cval(uint64_t v) {
  asm volatile("msr cntp_cval_el0, %0" :: "r"(v));
}

static inline void write_ctl(uint64_t v) {
  asm volatile("msr cntp_ctl_el0, %0" :: "r"(v));
  asm volatile("isb");
}

static uint64_t next_cval;

static inline void oneshot_us(uint64_t usec) {
  uint64_t ticks = (cntfrq() * usec) / 1'000'000ULL;
  next_cval = cntpct() + ticks;
  write_cval(next_cval);
  write_ctl(1);   // ENABLE=1, IMASK=0
}

static inline void rearm_periodic_us(uint64_t usec) {
  uint64_t ticks = (cntfrq() * usec) / 1'000'000ULL;
  next_cval += ticks;
  write_cval(next_cval);
  write_ctl(1);
}

} // namespace timer

/* ----------------------------------------------------------
 * IRQ handling
 * ---------------------------------------------------------- */

static constexpr uint32_t TIMER_IRQ = 30;

volatile uint64_t tick_count = 0;
static volatile bool print_tick = true;

void el1_irq_entry(void) {
  uint64_t intid = icc::read_iar1_el1();

  if (intid == TIMER_IRQ) {
    tick_count += 1;
    timer::rearm_periodic_us(1'000'000);

    if (print_tick) {
      kprintf("[irq] tick %lu\n", tick_count);
    }
  } else {
    kprintf("[irq] unexpected intid=%lu\n", intid);
  }

  icc::write_eoir1_el1(intid);
}

/* ----------------------------------------------------------
 * Public helpers
 * ---------------------------------------------------------- */

static inline void enable_ppi(uint32_t irq) {
  gicr::set_group1(GICR_BASE, irq);
  gicr::enable_ppi(GICR_BASE, irq);
}


#define TEST_TICKS_DEF 0
#if TEST_TICKS_DEF
static constexpr uint32_t test_ticks = 3;
#else
static constexpr uint32_t test_ticks = 0;
#endif

void gicv3_test_timer_irq(void) {
  GIC_LOG("* enabling timer IRQ\n");
  enable_ppi(TIMER_IRQ);

  GIC_LOG("* starting timer (1s)\n");
  timer::oneshot_us(1'000'000);

  while (tick_count < test_ticks) {
    asm volatile ("wfi");
  }

  print_tick = false;
}

/* ----------------------------------------------------------
 * Top-level init
 * ---------------------------------------------------------- */

void gicv3_init(void) {
  uart_func_enter("gicv3_init");

  daif_mask_all();

  GIC_LOG("* enable ICC system register interface\n");
  icc::enable_sysregs();

  GIC_LOG("* init distributor\n");
  gicd::init(GICD_BASE);

  GIC_LOG("* wake redistributor\n");
  gicr::wake(GICR_BASE);

  GIC_LOG("* set priority mask\n");
  icc::set_priority_mask();

  GIC_LOG("* enable Group 1 interrupts\n");
  icc::enable_group1();

  GIC_LOG("* unmask IRQs\n");
  daif_unmask_irq();

  gicv3_test_timer_irq();
}

} // extern "C"
