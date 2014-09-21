
#include <stdbool.h>
#include <stdint.h>
#include <c64.h>

#include "asm.h"
#include "gfx.h"


#define  CHAR_MATRIX  ((uint8_t*)0x0400)


int main (void)
{
  // Refer the VIC to the custom character set
  VIC.addr = ( ( (uint16_t)CHAR_MATRIX / 1024) << 4 )
             | ( ( (uint16_t)&CUSTOM_CHARSET / 2048) << 1 )
             ;

  zp_ptr = CHAR_MATRIX;
  while ( true )
  {
    function_in_asm( 1);
  }

  return 0;
}

