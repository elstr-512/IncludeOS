#ifndef EXCEPTION_HANDLING_H
#define EXCEPTION_HANDLING_H
#include <cstdint>
typedef void (*irq_handler_t)();
void register_handler(uint16_t irq, irq_handler_t handler);
void unregiser_handler(uint16_t irq);

#endif //EXCEPTION_HANDLING_H
