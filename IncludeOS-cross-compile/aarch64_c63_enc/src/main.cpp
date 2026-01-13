#include <os>
#include <service>

#include <stdio.h>

const unsigned char embedded_video[] = {
    #embed "foreman.yuv" // Clang extension
};

static void dump(const uint8_t arr[], size_t size)
{
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
    printf("Embedded data size: %zu bytes\n", sizeof(embedded_video));
    printf("data[]:\n");
    dump((const uint8_t*)embedded_video, sizeof embedded_video);
}

static void cpp_version() {
  switch (__cplusplus) {
    case 202302L: std::cout << "C++23"; break;
    case 202002L: std::cout << "C++20"; break;
    case 201703L: std::cout << "C++17"; break;
    case 201402L: std::cout << "C++14"; break;
    case 201103L: std::cout << "C++11"; break;
    case 199711L: std::cout << "C++98"; break;
    default:
    std::cout << "pre-standard C++ or custom standard";
  }
  std::cout << " (" << __cplusplus << ")\n";
}

void Service::start(const std::string& args){
  printf("Args = %s\n", args.c_str());

  cpp_version();

  puts("");
  embedded_test();
  puts("");

  printf("Service done. Shutting down...\n");
  os::shutdown();
}
