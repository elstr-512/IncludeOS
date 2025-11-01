// NOTE:
// just a callable function for a simple print
// in a c-file, call like this in assembly:
//
// bl kernel_aarch64_hello

#include <stdint.h>

volatile uint8_t *uart = (uint8_t *) 0x09000000;

void putchar(char c) {
  *uart = c;
}

void print(const char *s) {
  while(*s != '\0') {
    putchar(*s);
    s++;
  }
}

void kernel_aarch64_hello(void) {
  print("Hello aarch64 IncludeOS!\n");
}
