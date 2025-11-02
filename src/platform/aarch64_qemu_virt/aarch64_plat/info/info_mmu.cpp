#include "info_uart_print.hpp"

extern "C" {

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
static inline unsigned long read_esr_el1(void) {
  unsigned long v;
  asm volatile("mrs %0, esr_el1" : "=r"(v));
  return v;
}
static inline unsigned long read_far_el1(void) {
  unsigned long v;
  asm volatile("mrs %0, far_el1" : "=r"(v));
  return v;
}
static inline unsigned long read_elr_el1(void) {
  unsigned long v;
  asm volatile("mrs %0, elr_el1" : "=r"(v));
  return v;
}

void info_mmu() {
  uart_printf("\no-+-> info_mmu enter <-+-o \n");

  uart_printf("SCTLR_EL1 = %lx\n", read_sctlr_el1());
  uart_printf("TTBR0_EL1 = %lx\n", read_ttbr0_el1());
  uart_printf("TTBR1_EL1 = %lx\n", read_ttbr1_el1());
  uart_printf("TCR_EL1  =  %lx\n", read_tcr_el1());
  uart_printf("MAIR_EL1 =  %lx\n", read_mair_el1());
  uart_printf("ESR_EL1  =  %lx\n", read_esr_el1());
  uart_printf("FAR_EL1  =  %lx\n", read_far_el1());
  uart_printf("ELR_EL1  =  %lx\n", read_elr_el1());

  uart_printf("\nx-+-> info_mmu exit <-+-x \n");
}

} /* extern "C" */
