#pragma once

extern "C" {

void uart_putc(char c);
void uart_puts(const char* s);
void uart_flush(void);
void uart_printf(const char* fmt, ...);

void uart_puts_enter(const char* s);
void uart_puts_exit(const char* s);

} /* extern "C" */
