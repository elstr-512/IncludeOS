#include <cstdint>
#include <os>
#include <kernel/events.hpp>
#include <kernel/timers.hpp>
#include <kernel/rtc.hpp>

#include <kprint>
#include <kernel.hpp>
#include <kernel/rng.hpp>
#include <timer.h>

#include <info>

#include <hw/pci_manager.hpp>

#include <smp>

extern "C" {
#include <libfdt.h>
}

#include <cpu.h>

#include "exception_handling.hpp"
#include "gic.h"

extern "C" void noop_eoi() {}
extern "C" void cpu_sampling_irq_handler() {}
extern "C" void blocking_cycle_irq_handler() {}

extern "C" void vm_exit();

/*
void (*current_eoi_mechanism)() = noop_eoi;
void (*current_intr_handler)() = nullptr;
*/


void __platform_init(uint64_t fdt_addr)
{
  INFO("aarch64", "__platform_init");

  const char *fdt=(const char *)fdt_addr;

  INFO("FDT", "fdt addr %p", (void *)fdt_addr);

  // Validate FDT header
  int res = fdt_check_header(fdt);
  if (res != 0) {
    INFO2("Invalid FDT header!");
    return;
  }
  INFO2("FDT header OK!");

  // Print model name (if available)
  int root = fdt_path_offset(fdt, "/");
  if (root >= 0) {
    const char *model = (char*) fdt_getprop(fdt, root, "model", NULL);
    if (model) {
      INFO("FDT", "Model: %s", model);
    }
  }

  // Count the nodes
  int node;
  uint32_t node_count = 0;
  fdt_for_each_subnode(node, fdt, root) {
    node_count++;
  }
  INFO("FDT", "Root subnode count: %d", node_count);


  const int intc = fdt_path_offset(fdt, "/intc");

  if (intc < 0) //interrupt controller not found in fdt.. should never happen..
  {
    printf("interrupt controller not found in dtb\r\n");
    return;
  }
  if (fdt_node_check_compatible(fdt,intc,"arm,cortex-a15-gic") == 0)
  {
    printf("init gic (arm,cortex-a15-gic)\r\n");
    gic_init_fdt(fdt,intc);
  }

  Events::get(0).init_local();

  struct alignas(SMP_ALIGN) timer_data
  {
    int  intr;
    bool intr_enabled = false;
  };
  static SMP::Array<timer_data> timerdata;

  // Scan PCI buses
  // hw::PCI_manager::init();

#define TIMER_IRQ 27

  //frequency is in ticks per second
  static uint32_t ticks_per_micro = timer_get_frequency()/1000000;

  Timers::init(
    [](Timers::duration_t nanos){

      //there is a better way to do this!!
      // prevent overflow
      uint64_t ticks = (nanos.count() / 1000)* ticks_per_micro;
      if (ticks > 0xFFFFFFFF)
        ticks = 0xFFFFFFFF;
        // prevent oneshots less than a microsecond
        // NOTE: when ticks == 0, the entire timer system stops
      else if (UNLIKELY(ticks < ticks_per_micro))
        ticks = ticks_per_micro;

      timer_set_virtual_compare(timer_get_virtual_countval()+ticks);
      timer_virtual_start();
    },
    [](){
      timer_virtual_stop();
    }
  );

  /* TODO figure out what these are for
  PER_CPU(timerdata).intr=TIMER_IRQ;
  Events::get().subscribe(TIMER_IRQ,Timers::timers_handler);
*/
  //regiser the event handler for the irq.. ?
  register_handler(TIMER_IRQ,&Timers::timers_handler);

  gicd_set_config(TIMER_IRQ,GICD_ICFGR_EDGE);
  //highest possible priority
  gicd_set_priority(TIMER_IRQ,0);
  //TODO get what core we are on
  gicd_set_target(TIMER_IRQ,0x01); //target is processor 1
  gicd_irq_clear(TIMER_IRQ);

  gicd_irq_enable(TIMER_IRQ);

  //cpu_fiq_enable();
  cpu_irq_enable();
  //cpu_serror_enable();

  RTC::init();

  Timers::ready();
}


void __arch_poweroff()
{

  kprint("[ aarch64 ] poweroff (what.?)\n");

  // QEMU Hypervisor call -> power off
  // -----------

  asm volatile ("ldr x0, =0x84000008");
  asm volatile ("hvc     #0");

  __builtin_unreachable();
}

void RNG::init()
{
  size_t random = 4; // one of the best random values
  rng_absorb(&random, sizeof(random));
}


// not supported!
uint64_t __arch_system_time() noexcept {
  //in nanoseconds..
  return ((timer_get_virtual_countval()*10)/(timer_get_frequency()/100000))*1000;
  //return 0;
}
timespec __arch_wall_clock() noexcept {
  return {0, 0};
}
// not supported!

// default to serial
void kernel::default_stdout(const char* str, const size_t len)
{
  __serial_print(str, len);
}

void __arch_reboot()
{
  kprint("ARCH REBOOT WHY ?\r\n");
  //TODO
}
/*
void __arch_enable_legacy_irq(unsigned char){}
void __arch_disable_legacy_irq(unsigned char){}
*/

void SMP::global_lock() noexcept {}
void SMP::global_unlock() noexcept {}
int SMP::cpu_id() noexcept { return 0; }
int SMP::cpu_count() noexcept { return 1; }



// default stdout/logging states
__attribute__((weak))
bool os_enable_boot_logging = false;
__attribute__((weak))
bool os_default_stdout = false;
