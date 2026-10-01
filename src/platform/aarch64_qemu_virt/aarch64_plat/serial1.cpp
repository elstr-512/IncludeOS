#include <hw/serial.hpp>
#include <stdarg.h>

extern "C" {

static const uint32_t UART_BASE=0x09000000;

void __serial_print1(const char* cstr)
{
  while (*cstr) {
    //No check what so ever probably not ok
    *((volatile unsigned int *) UART_BASE) = *cstr++;
  }
}

void __serial_print(const char* str, size_t len)
{
  for (size_t i = 0; i < len; i++) {
    *((volatile unsigned int *) UART_BASE) = str[i];
  }
}

void kprint(const char* c){
  __serial_print1(c);
}

void kprintf(const char* format, ...)
{
  char buf[8192];
  va_list aptr;
  va_start(aptr, format);
  vsnprintf(buf, sizeof(buf), format, aptr);
  __serial_print1(buf);
  va_end(aptr);
}

}
