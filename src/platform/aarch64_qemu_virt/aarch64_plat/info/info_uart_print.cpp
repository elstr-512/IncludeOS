/*
 * info_uart_print.cpp
 *
 * Minimal UART debug printing for early AArch64 boot.
 *
 * This is intended as an AARCH64 *fallback* logging mechanism when:
 *  - the MMU is not enabled
 *  - the heap is not available
 *  - other logging libs may cause unaligned memory accesses
 *
 * Target:
 *  - QEMU AArch64 "virt" machine
 *
 * Supported printf format specifiers:
 *  - %c : character
 *  - %s : C-string
 *  - %d : signed decimal integer
 *  - %x : unsigned hexadecimal integer
 *
 * Everything else is printed literally.
 */

extern "C" {

#include "info_uart_print.hpp"
#include <cstdarg>
#include <cstdint>

/* --------------------------------------------------------------------------
 * UART register definitions (QEMU virt)
 * -------------------------------------------------------------------------- */

/* Base address of PL011 UART0 on QEMU virt */
#define UART0_BASE 0x09000000UL

/* Data Register */
#define UART0_DR (*(volatile uint32_t*)(UART0_BASE + 0x00))

/* Flag Register */
#define UART0_FR (*(volatile uint32_t*)(UART0_BASE + 0x18))

/* Transmit FIFO full flag */
#define UART_FR_TXFF (1 << 5)

/* --------------------------------------------------------------------------
 * Low-level UART output
 * -------------------------------------------------------------------------- */

/*
 * Send a single character over UART.
 * Busy-waits until the transmit FIFO has space.
 */
void uart_putc(char c)
{
  /* Wait while transmit FIFO is full */
  while (UART0_FR & UART_FR_TXFF) {
    /* spin */
  }

  UART0_DR = static_cast<uint32_t>(c);
}

/*
 * Send a null-terminated string over UART.
 */
void uart_puts(const char* s)
{
  if (!s) {
    return;
  }

  while (*s) {
    uart_putc(*s++);
  }
}

/* --------------------------------------------------------------------------
 * Integer formatting helpers
 * -------------------------------------------------------------------------- */

/*
 * Print an unsigned integer as hexadecimal.
 * No prefix (0x) is added.
 */
static void uart_puthex(uint64_t value)
{
  static const char* digits = "0123456789abcdef";

  /* Print at least one digit */
  bool started = false;

  for (int i = 7; i >= 0; --i) {
    uint8_t nibble = (value >> (i * 4)) & 0xF;

    if (nibble || started || i == 0) {
      uart_putc(digits[nibble]);
      started = true;
    }
  }
}

/*
 * Print a signed integer in decimal.
 */
static void uart_putdec(int value)
{
  char buffer[16];
  int index = 0;

  if (value == 0) {
    uart_putc('0');
    return;
  }

  /* Handle negative numbers */
  if (value < 0) {
    uart_putc('-');
    value = -value;
  }

  /* Convert digits in reverse order */
  while (value && index < static_cast<int>(sizeof(buffer))) {
    buffer[index++] = '0' + (value % 10);
    value /= 10;
  }

  /* Output digits in correct order */
  while (index--) {
    uart_putc(buffer[index]);
  }
}

/* --------------------------------------------------------------------------
 * Minimal printf implementation
 * -------------------------------------------------------------------------- */

/*
 * Core vprintf-style formatter.
 * Supports: %c, %s, %d, %x
 */
static void uart_vprintf(const char* fmt, va_list args)
{
  while (*fmt) {
    if (*fmt != '%') {
      uart_putc(*fmt++);
      continue;
    }

    /* Skip '%' */
    ++fmt;

    switch (*fmt) {
      case 'c': {
        char c = static_cast<char>(va_arg(args, int));
        uart_putc(c);
        break;
      }

      case 's': {
        const char* s = va_arg(args, const char*);
        uart_puts(s ? s : "(null)");
        break;
      }

      case 'd': {
        int value = va_arg(args, int);
        uart_putdec(value);
        break;
      }

      case 'x': {
        uint64_t value = va_arg(args, uint64_t);
        uart_puthex(value);
        break;
      }

      case '%':
        uart_putc('%');
        break;

      default:
        /* Unknown format specifier: print literally */
        uart_putc('%');
        uart_putc(*fmt);
        break;
    }

    ++fmt;
  }
}

/*
 * printf-style UART output.
 * Supported printf format specifiers:
 * - %c : character
 * - %s : C-string
 * - %d : signed decimal integer
 * - %x : unsigned hexadecimal integer
 */
void uart_printf(const char* fmt, ...)
{
  va_list args;
  va_start(args, fmt);
  uart_vprintf(fmt, args);
  va_end(args);
}

/* --------------------------------------------------------------------------
 * Optional helpers
 * -------------------------------------------------------------------------- */

/*
 * Mark function entry in UART output.
 * Useful for tracing early boot execution flow.
 */
void uart_func_enter(const char* name)
{
  uart_printf("\n[ENTER] %s\n", name);
}

/*
 * Mark function exit in UART output.
 */
void uart_func_exit(const char* name)
{
  uart_printf("[EXIT ] %s\n", name);
}

} /* extern "C" */
