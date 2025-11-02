
extern "C" {

void handle_exception(unsigned type, unsigned long esr, unsigned long far,
                      unsigned long spsr, unsigned long elr);

void handle_exception(unsigned type, unsigned long esr, unsigned long far,
                      unsigned long spsr, unsigned long elr) {

  // For early bringup, print registers and spin.
  for(;;) { asm volatile("wfe"); } // trap for debugging
}

} /* extern "C" */
