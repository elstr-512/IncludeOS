#pragma once

extern "C" {

void uart_putc(char c);
void uart_puts(const char* s);
void uart_flush(void);
void uart_printf(const char* fmt, ...);

} /* extern "C" */
