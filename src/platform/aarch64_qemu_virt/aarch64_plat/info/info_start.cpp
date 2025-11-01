#include <cstdint>

extern "C" {
  #include <libfdt.h>
}


extern "C" {

// NOTE: UART base on QEMU virt
#define UART0_BASE 0x09000000UL
#define UART0_DR   (*(volatile uint32_t *)(UART0_BASE + 0x00))
#define UART0_FR   (*(volatile uint32_t *)(UART0_BASE + 0x18))

static void uart_putc(char c) {
  while (UART0_FR & (1 << 5)) ;
  UART0_DR = c;
}

static void uart_puts(const char *s) {
  while (*s) uart_putc(*s++);
}

static uint64_t read_current_el(void) {
  uint64_t el;
  asm volatile ("mrs %0, CurrentEL" : "=r"(el));
  return (el >> 2) & 0x3;
}

static uint64_t read_sctlr_el1(void) {
  uint64_t v;
  asm volatile ("mrs %0, SCTLR_EL1" : "=r"(v));
  return v;
}

static void print_boot_state(void) {
  uint64_t el = read_current_el();
  uint64_t sctlr = read_sctlr_el1();
  uart_puts("\n--- Boot State --- \n");
  uart_puts("EL: "); uart_putc('0' + el); uart_puts("\n");
  uart_puts((sctlr & 1) ? "MMU: enabled\n" : "MMU: disabled\n");
}

// Arguments for aarch64, dtb_addr32 = x0
void info_kernel_main(uint64_t dtb_addr32, uint64_t x1, uint64_t x2, uint64_t x3) {

  uart_puts("\no-+-> info_kernel_main enter <-+-o \n");

  print_boot_state();

  if(dtb_addr32 == 0) {
    // NOTE: set to default qemu-system-aarch64 location
    const uint64_t qemu_dtb_default = 0x40000000;
    dtb_addr32 = qemu_dtb_default;
  }

  // Mask upper bits since DTB address in x0 is 32-bit
  const uint64_t DTB_32_BIT_MASK = 0xFFFFFFFF;
  dtb_addr32 &= DTB_32_BIT_MASK;


  uart_puts("\n--- Device Tree State --- \n");
  void *fdt = (void *)dtb_addr32;

  // Validate FDT header
  int res = fdt_check_header(fdt);
  if (res != 0) {
    uart_puts("Invalid FDT header! \n");
    return;
  }
  uart_puts("FDT header OK! \n");

  // Print model name (if available)
  int root = fdt_path_offset(fdt, "/");
  if (root >= 0) {
    const char *model = (char*) fdt_getprop(fdt, root, "model", NULL);
    if (model) {
      uart_puts("Model: ");
      uart_puts(model);
      uart_puts("\n");
    }
  }


  // Parse some nodes
  int node;
  char *name = NULL;

  uart_puts("\n--- List FDT node names --- \n");

  fdt_for_each_subnode(node, fdt, root) {
    name = (char*) fdt_get_name(fdt, node, NULL);
    if (name) {
      uart_puts("\t");
      uart_puts(name);
    }
  }
  uart_puts("\n");

  uart_puts("\nx-+-> info_kernel_main exit <-+-x \n");
  uart_puts("\n");
}

} /* extern "C" */
