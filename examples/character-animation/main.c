
#include <stdbool.h>
#include <stdint.h>
#include <string.h> // for memcpy()
#include <c64.h>

#include "asm.h"


#define _RASTER_DEBUG


#define  CHAR_MATRIX     ((uint8_t*) 0x0400)
#define  CUSTOM_CHARSET  ((uint8_t*) 0x2000)


void init( void)
{
  asm_init();

  // Refer the VIC to the custom character set
  VIC.addr = ( ( (uint16_t)CHAR_MATRIX / 1024) << 4 )
           | ( ( (uint16_t)CUSTOM_CHARSET / 2048) << 1 )
           ;

  VIC.imr = 0x01; // Enable "raster compare" interrupts
  VIC.ctrl1 &= 0x7f; // Set the 9th bit of the raster compare register to 0
  VIC.rasterline = 248; // The beginning of the bottom border by experiment with PAL version
}


void raster_interrupt_handler( void)
{
  static uint8_t  frame = 0;

  #ifdef _RASTER_DEBUG
  // Change the border color to white so it's easy to get an idea of how many
  // cycles the interrupt handler uses
  VIC.bordercolor = 1;
  #endif

  // Copy the glyph data for the current frame to the character code that the
  // background refers to
  memcpy( &CUSTOM_CHARSET[' '<<3], &CUSTOM_CHARSET[(0x80+frame)<<3], 8 );
  frame += 1;
  if ( 20 <= frame)
    frame = 0;

  #ifdef _RASTER_DEBUG
  VIC.bordercolor = 0;
  #endif
}


int main (void)
{
  init();

  while( true)
  {
  }

  return 0;
}

