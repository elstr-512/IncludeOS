#include "info_uart_print.hpp"

#include <cstdint>
#include <cstdarg>

extern "C" {

// NOTE: UART base on QEMU virt
#define UART0_BASE 0x09000000UL
#define UART0_DR   (*(volatile uint32_t *)(UART0_BASE + 0x00))
#define UART0_FR   (*(volatile uint32_t *)(UART0_BASE + 0x18))

void uart_putc(char c) {
  while (UART0_FR & (1 << 5)) ;
  UART0_DR = c;
}

void uart_puts(const char* s) {
  while (*s) uart_putc(*s++);
}

void uart_flush(void) {
    while (UART0_FR & (1 << 3)) ;  // Bit 3 = BUSY
}

static void uart_puthex(uint64_t x) {
  static const char* hex = "0123456789abcdef";
  uart_puts("0x");
  bool started = false;
  for (int i = (sizeof(x) * 2) - 1; i >= 0; --i) {
    uint8_t nib = (x >> (i * 4)) & 0xF;
    if (nib || started || i == 0) {
      uart_putc(hex[nib]);
      started = true;
    }
  }
}

static void uart_putdec(long x) {
  char buf[32];
  int i = 0;
  bool neg = false;
  if (x == 0) {
    uart_putc('0');
    return;
  }
  if (x < 0) {
    neg = true;
    x = -x;
  }
  while (x && i < 31) {
    buf[i++] = '0' + (x % 10);
    x /= 10;
  }
  if (neg) uart_putc('-');
  while (i--) uart_putc(buf[i]);
}

static void uart_vprintf(const char* fmt, va_list args) {
  for (; *fmt; ++fmt) {
    if (*fmt != '%') {
      uart_putc(*fmt);
      continue;
    }

    ++fmt; // skip '%'
    switch (*fmt) {
      case '%':
        uart_putc('%');
        break;
      case 's': {
        const char* s = va_arg(args, const char*);
        uart_puts(s ? s : "(null)");
        break;
      }
      case 'c': {
        char c = (char)va_arg(args, int);
        uart_putc(c);
        break;
      }
      case 'd': {
        int val = va_arg(args, int);
        uart_putdec(val);
        break;
      }
      case 'x': {
        unsigned int val = va_arg(args, unsigned int);
        uart_puthex(val);
        break;
      }
      case 'l': {  // support %lx
        ++fmt;
        if (*fmt == 'x') {
          unsigned long val = va_arg(args, unsigned long);
          uart_puthex(val);
        }
        break;
      }
      case 'p': {
        uintptr_t ptr = va_arg(args, uintptr_t);
        uart_puthex(ptr);
        break;
      }
      default:
        uart_putc('%');
        uart_putc(*fmt);
        break;
    }
  }
}

void uart_printf(const char* fmt, ...) {
  va_list args;
  va_start(args, fmt);
  uart_vprintf(fmt, args);
  va_end(args);
}

} /* extern "C" */
