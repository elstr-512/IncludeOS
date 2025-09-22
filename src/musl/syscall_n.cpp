#include "stub.hpp"

long syscall(long /*number*/)
{
  return -ENOSYS;
}

#if defined(ARCH_aarch64)
inline long syscall_n(long i) {
  // stub: do nothing or return ENOSYS
  return -ENOSYS;
}
#else
extern "C"
long syscall_n(long i) {
  return stubtrace(syscall, "syscall", i);
}
#endif
