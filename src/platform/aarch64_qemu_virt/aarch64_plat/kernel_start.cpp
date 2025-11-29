//
//
//
//
//
//
// hello
//
//
//
//
//
//
//
//

#include "init_libc.hpp"
#include <cpu.h>
#include <kernel.hpp>
#include <kernel/diag.hpp>
#include <kernel/rng.hpp>
#include <kernel/service.hpp>
#include <kprint>
#include <os.hpp>
#include <os>

#include <cstdint>

extern "C" {
  #include <libfdt.h>
}


#define KERN_DEBUG_AARCH64 1
#ifdef KERN_DEBUG_AARCH64
#define KDEBUG_AARCH64(fmt, ...) kprintf(fmt, ##__VA_ARGS__)
#else
#define KDEBUG_AARCH64(fmt, ...) /* fmt */
#endif

extern "C" {
  void __init_sanity_checks();
  void kernel_sanity_checks();
  void _init_bss();
  uintptr_t _move_symbols(uintptr_t loc);
  void _init_elf_parser();
  void __init_crash_contexts();
  void __elf_validate_section(const void*);
}


namespace kernel::diag {
  void __attribute__((weak)) post_bss() noexcept {}
  void __attribute__((weak)) post_machine_init() noexcept {}
}

uintptr_t _multiboot_free_begin(uintptr_t boot_addr);
uintptr_t _multiboot_memory_end(uintptr_t boot_addr);

/*extern bool os_default_stdout;*/

extern "C"
void _init_bss()
{
  extern char _BSS_START_, _BSS_END_;
  __builtin_memset(&_BSS_START_, 0, &_BSS_END_ - &_BSS_START_);
}


static os::Machine* __machine = nullptr;
os::Machine& os::machine() noexcept {
  LL_ASSERT(__machine != nullptr);
  return *__machine;
}

const char* os::Machine::name() noexcept {
  return "aarch64";
}

// aarch64 kernel start
extern "C"
void kernel_start(uintptr_t magic, uintptr_t addrin)
{
  #warning "aarch64: x86_64 copy-paste"
  KDEBUG_AARCH64("\n//////////////////  IncludeOS kernel start ////////////////// \n");
  KDEBUG_AARCH64("* Booted with magic 0x%x, grub @ 0x%x \n",
          magic, addrin);

  // generate checksums of read-only areas etc.
  __init_sanity_checks();

  kprintf("CurrentEL: %d\n", cpu_get_current_el());

  // Determine where free memory starts
  extern char _end;
  uintptr_t free_mem_begin = reinterpret_cast<uintptr_t>(&_end);
  uintptr_t memory_end     = kernel::memory_end();

  // HACK: this is HARDCODED for qemu-system-aarch64 atm
  uint64_t addr = 0x40000000;     // dram start
  uint64_t size = 0x40000000;     // dram size
  uint64_t fdt_addr = 0x40000000; // fdt position
  void *fdt = (void*)fdt_addr;    // fdt pointer

  uint64_t _memory_end = addr + size;
  memory_end = reinterpret_cast<uintptr_t>(_memory_end);

  if ( fdt_check_header(fdt) != 0 )
  {
    kprint("FDT Header check failed\r\n");
    return;
  }

  KDEBUG_AARCH64("* Free mem begin: 0x%zx, memory end: 0x%zx \n",
          free_mem_begin, memory_end);

  KDEBUG_AARCH64("* Moving symbols. \n");
  // Preserve symbols from the ELF binary
  free_mem_begin += _move_symbols(free_mem_begin);
  KDEBUG_AARCH64("* Free mem moved to: %p \n", (void*) free_mem_begin);


  KDEBUG_AARCH64("* Init .bss\n");
  _init_bss();
  kernel::diag::hook<kernel::diag::post_bss>();

  // Instantiate machine
  size_t memsize = memory_end - free_mem_begin;
  __machine = os::Machine::create((void*)free_mem_begin, memsize);

  KDEBUG_AARCH64("* Init ELF parser\n");
  _init_elf_parser();

  // Begin portable HAL initialization
  __machine->init();
  kernel::diag::hook<kernel::diag::post_machine_init>();

  // TODO: Move more stuff into Machine::init
  // TODO: aarch64 SMP ENABLE
  RNG::init();

  KDEBUG_AARCH64("* Init per CPU crash contexts\n");
  __init_crash_contexts();

  KDEBUG_AARCH64("* Init CPU exceptions (not implemented)\n");
  #warning "EXCEPTIONS not implemented"

  //probably not very sane!
  cpu_debug_enable();
  cpu_fiq_enable();
  cpu_irq_enable();
  cpu_serror_enable();

  aarch64::init_libc((uintptr_t)fdt_addr);
}
