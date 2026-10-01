#pragma once

extern "C" {

/* C IRQ handler entry */
void el1_irq_entry(void);

/* Top-level init to call from boot after stack + basic mmu mapping exist */
void gicv3_init(void);

} /* extern "C" */
