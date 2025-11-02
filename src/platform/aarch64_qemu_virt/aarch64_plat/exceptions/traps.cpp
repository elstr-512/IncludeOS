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
  uart_printf("[EXCEPTION] type=%d ESR=%lx FAR=%lx ELR=%lx\n",
              type, esr, far, elr);

  asm volatile("wfe");
  for (;;) asm volatile("wfe");


  uart_puts_exit("exception_entry");
}

} /* extern "C" */
