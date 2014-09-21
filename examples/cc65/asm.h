
#ifndef __ASM_H
#define __ASM_H


extern uint8_t *zp_ptr;
#pragma zpsym("zp_ptr");

extern void __fastcall__  function_in_asm( uint8_t parameter );


#endif

