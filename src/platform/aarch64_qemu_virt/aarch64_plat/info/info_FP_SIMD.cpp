#include "info_uart_print.hpp"

#include <arm_neon.h>
#include <cstdint>

extern "C" {

// Arguments for aarch64, dtb_addr32 = x0
void info_FP_SIMD(void) {

  uart_puts("\no-+-> info_FP_SIMD enter <-+-o \n");

  uart_printf("\n--- Testing floats ---\n");
  double fa = 12.4321;
  double fb = 67.9876;
  double fc = 80.4197;

  if ( (fa + fb) == fc) {
    uart_printf("floats OK! \n");
  }

  uart_printf("\n--- Testing SIMD ---\n");
  uint32x4_t va = {1, 2, 3, 4};
  uint32x4_t vb = {10, 20, 30, 40};
  uint32x4_t vc = vaddq_u32(va, vb);
  uint32_t result[4];
  vst1q_u32(result, vc);

  bool simd_check =
    va[0] + vb[0] == result[0] &&
    va[1] + vb[1] == result[1] &&
    va[2] + vb[2] == result[2] &&
    va[3] + vb[3] == result[3];

  if (simd_check) {
    uart_printf("SIMD test result: %d %d %d %d\n",
                result[0], result[1], result[2], result[3]);

    uart_printf("SIMD OK! \n");
  }

  uart_puts("\nx-+-> info_FP_SIMD exit <-+-x \n");
  uart_puts("\n");
}

} /* extern "C" */
