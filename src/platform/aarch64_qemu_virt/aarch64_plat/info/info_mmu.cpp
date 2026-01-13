
extern "C" {

#include "info_uart_print.hpp"

static inline unsigned long read_sctlr_el1(void) {
  unsigned long v;
  asm volatile("mrs %0, sctlr_el1" : "=r"(v));
  return v;
}

static inline unsigned long read_ttbr0_el1(void) {
  unsigned long v;
  asm volatile("mrs %0, ttbr0_el1" : "=r"(v));
  return v;
}

static inline unsigned long read_ttbr1_el1(void) {
  unsigned long v;
  asm volatile("mrs %0, ttbr1_el1" : "=r"(v));
  return v;
}

static inline unsigned long read_tcr_el1(void) {
  unsigned long v;
  asm volatile("mrs %0, tcr_el1" : "=r"(v));
  return v;
}

static inline unsigned long read_mair_el1(void) {
  unsigned long v;
  asm volatile("mrs %0, mair_el1" : "=r"(v));
  return v;
}

static inline unsigned long read_ID_AA64MMFR0_EL1(void) {
  unsigned long v;
  asm volatile("mrs %0,ID_AA64MMFR0_EL1" : "=r"(v));
  return v;
}

void info_mmu() {
  uart_func_enter("info_mmu");

  uart_printf("SCTLR_EL1 = 0x%x\n", read_sctlr_el1());
  uart_printf("TTBR0_EL1 = 0x%x\n", read_ttbr0_el1());
  uart_printf("TTBR1_EL1 = 0x%x\n", read_ttbr1_el1());
  uart_printf("TCR_EL1   = 0x%x\n", read_tcr_el1());
  uart_printf("MAIR_EL1  = 0x%x\n", read_mair_el1());
  uart_printf("ID_AA64MMFR0_EL1 = 0x%x\n\n\n", read_ID_AA64MMFR0_EL1());
}

} /* extern "C" */
