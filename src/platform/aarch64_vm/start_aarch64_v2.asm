#include <macros.h>

//exception.asm
.text
.align 8
.globl _start
.extern exception_vector
.extern __boot_magic
.extern __stack_top
_start:
    // code0/code1
    nop
    b reset

    // text_offset
    .quad 0

    // image_size
    .quad _end - _start

    // flags
    .quad 0b1010

    // Reserved fields
    .quad 0
    .quad 0
    .quad 0

    // magic - yes 0x644d5241 is the same as ASCII string "ARM\x64"
    .ascii "ARM\x64"

    // Another reserved field at the end of the header
    .byte 0, 0, 0, 0


.globl reset

reset:
  // save x0
  mov x9, x0
 // in case someone one day provides us with a cookie
  ldr x8 , __boot_magic
  str x0, [x8]


        //load the exception vector to x0
        //different tables for different EL's but thats a given..
        adr     x0, exception_vector
        msr     daifset, #0xF //disable all exceptions

        //do we need this switch?
        mrs     x1, CurrentEL //load current execution level
        cmp     x1, 0xc
        b.eq    3f
        cmp     x1, 0x8
        b.eq    2f
        cmp     x1, 0x4
        b.eq    1f
3:      msr     vbar_el3, x0
        mrs     x0, scr_el3
        orr     x0, x0, #0xf                    /* SCR_EL3.NS|IRQ|FIQ|EA */
        msr     scr_el3, x0
        msr     cptr_el3, xzr                   /* Enable FP/SIMD */

        b       0f
2:      msr     vbar_el2, x0
        mov     x0, #0x33ff
        msr     cptr_el2, x0                    /* Enable FP/SIMD */
        b       0f
1:      msr     vbar_el1, x0
        mov     x0, #3 << 20
        msr     cpacr_el1, x0                   /* Enable FP/SIMD */
0:

  // restore x0
  mov x0, x9

  // stack
  ldr x8 , =__stack_top
  mov sp, x8

  bl kernel_start

loop:
  b loop
