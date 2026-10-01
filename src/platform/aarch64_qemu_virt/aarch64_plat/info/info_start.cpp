
extern "C" {
  #include <libfdt.h>
}

extern "C" {

#include "info_uart_print.hpp"
#include <cstdint>

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
  uart_puts("\n--- Boot State --- \n");
  uart_printf("EL: %d\n", read_current_el());
  uart_puts(
    (read_sctlr_el1() & 1) ? "MMU: enabled\n" : "MMU: disabled\n"
  );
}

constexpr uint64_t qemu_dtb_default = 0x40000000;
// Arguments for aarch64.
// After boot (with bootloader using the linux boot protocol, like u-boot)
// dtb_addr32 should be in register -> x0.
// qemu does not do this, for qemu just hardcode location...
void info_kernel_main(uint64_t dtb_addr32, uint64_t x1, uint64_t x2, uint64_t x3) {

  uart_func_enter("info_kernel_main");
  uart_printf("registers: x0 = %x, x1 = %x, x2 = %x, x3 = %x\n", dtb_addr32, x1, x2, x3);

  print_boot_state();

  if(dtb_addr32 == 0) {
    // NOTE: set to default qemu-system-aarch64 location
    dtb_addr32 = qemu_dtb_default;
  }

  // Mask upper bits since DTB address in x0 is 32-bit
  const uint64_t DTB_32_BIT_MASK = 0xFFFFFFFF;
  dtb_addr32 &= DTB_32_BIT_MASK;


  uart_puts("\n--- Device Tree State --- \n");
  uart_printf("dtb addr32: 0x%x\n", dtb_addr32);
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

  int line_number = 1;

  fdt_for_each_subnode(node, fdt, root) {
    name = (char*) fdt_get_name(fdt, node, NULL);
    if (name) {
      uart_puts(name);
    }

    if (line_number % 7 == 0) {
      uart_puts("\n");
    } else {
      uart_puts("\t");
    }
    line_number++;
  }
  uart_puts("\n");

}

} /* extern "C" */
