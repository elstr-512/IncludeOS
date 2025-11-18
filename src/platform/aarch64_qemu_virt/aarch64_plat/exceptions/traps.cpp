#include "../info/info_uart_print.hpp"

extern "C" {

void exception_entry(unsigned type,
                     unsigned long esr,
                     unsigned long far,
                     unsigned long spsr,
                     unsigned long elr)
{
  uart_puts_enter("exception_entry");

  // Early bring-up: just print and hang
  uart_printf("[EXCEPTION] type=%d ESR=%lx FAR=%lx SPSR=%lx ELR=%lx\n",
              type, esr, far, spsr, elr);

  // decode with: aarch64-esr-decoder
  uart_printf("[ESR] %lx\n", esr);

  // spin.
  asm volatile("wfe");
  for (;;) asm volatile("wfe");

}

} /* extern "C" */
