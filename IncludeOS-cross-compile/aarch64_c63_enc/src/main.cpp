#include <cstddef>
#include <os>
#include <service>

#include <stdio.h>

extern "C" {
  extern const unsigned char __binary_yuv_start[];
  extern const unsigned char __binary_yuv_end[];

  const size_t __binary_yuv_size =
    __binary_yuv_end - __binary_yuv_start;
}

static void dump(const uint8_t arr[], size_t size) {
    for (
      size_t i = 0;
      i != size && i < (10 * 16);
      ++i
    ) {
      if ( i % 16 == 0) { printf("%08zx  ", i); }
      else if ( i % 8 == 0) { printf(" "); }
      printf("%02x%c", arr[i], (i + 1) % 16 ? ' ' : '\n');
    }

    puts("");
}

static void embedded_test() {
  printf("Embedded data size: %zu bytes\n", __binary_yuv_size);
  dump(__binary_yuv_start, __binary_yuv_size);
}

void Service::start(const std::string& args) {
  printf("Args = %s\n", args.c_str());

  puts("");
  embedded_test();
  puts("");

  printf("Service done. Shutting down...\n");
  os::shutdown();
}
