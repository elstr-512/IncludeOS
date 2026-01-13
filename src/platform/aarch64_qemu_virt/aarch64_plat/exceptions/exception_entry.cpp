
extern "C" {

#include "../info/info_uart_print.hpp"
#include "gicv3.hpp"

void exception_entry(unsigned type,
                     unsigned long esr,
                     unsigned long far,
                     unsigned long spsr,
                     unsigned long elr)
{

  switch (type) {
    case 5: /* irq */
      el1_irq_entry();
      break;

    default: /* just print and hang */
      uart_printf("[EXCEPTION] type=%d ESR=0x%x FAR=0x%x SPSR=0x%x ELR=0x%x\n",
                  type, esr, far, spsr, elr);
      uart_printf("[EXCEPTION] decode ESR with: aarch64-esr-decoder\n");
      uart_printf("[ESR] 0x%x\n", esr);

      // spin.
      while(1) asm volatile("wfe");
  }

}

} /* extern "C" */
