/*

I wrote this to try to understand how the sprite to background collision and
priority works.

The summary is that:

  + For a sprite, any of the three colors that aren't background color are
    involved in collisions

  + For a character, %00 AND %01 are considered background in two ways:

      1) They are not involved in collisions

      2) They are drawn *behind* sprites even when the sprite priority flag
         indicates that background should occlude the sprite.  %10 and %11 by
         contrast *do* occlude the sprite when its priority flag is set

*/

#include <stdbool.h>
#include <stdint.h>
#include <string.h>
#include <c64.h>
#include <6502.h>
#include <conio.h>

#include "joystick.h"


#define  RAM              ((uint8_t*) 0x0000)
#define  SHAPE_FOR_SPRITE ((uint8_t*) 0x07f8)
#define  CHARACTER_ROM    ((uint8_t*) 0xd000)
#define  CHAR_MATRIX      ((uint8_t*) 0x0400)
#define  CUSTOM_CHARS     ((uint8_t*) 0x3000)


void init()
{
  VIC.ctrl2 = ( 0 << 5) // 0: do not reset the VIC-II
            | ( 1 << 4) // 1: multi-color mode
            | ( 1 << 3) // 0: 38-column mode for fine horizontal scrolling
            | ( 0 << 0) // 0..7: fine horizontal scrolling
            ;
  VIC.bgcolor0 = COLOR_BLACK; // for a %00 pixel in either characters or sprites
  VIC.bgcolor1 = COLOR_WHITE; // for a %01 pixel in characters
  VIC.bgcolor2 = COLOR_GRAY1; // for a %02 pixel in characters
  VIC.spr_mcolor = 1 << 0; // Sprite #0 should be multi-color
  VIC.spr0_color = COLOR_LIGHTRED;  // for a %10 pixel in sprites
  VIC.spr_mcolor0 = COLOR_BROWN;    // for a %01 pixel in sprites
  VIC.spr_mcolor1 = COLOR_GRAY2;    // for a %11 pixel in sprites
  SHAPE_FOR_SPRITE[0] = 0x2000 / 64; // Can't work out how to pull the 0x2000 from the linker config file
  VIC.spr0_x = 24+320/2 - 24/2;
  VIC.spr0_y = 48+200/2 - 21/2;
  VIC.spr_ena = 1 << 0; // Enable Sprite #0

  // Copy the first 2K of the character ROM to RAM
  // The VIC sees the character ROM at $1000..$1fff and $9000..9fff although
  // the CPU sees it only at $d000 and only when I/O ( normally at $d000) is
  // paged out.
  SEI(); // Disable IRQs in case the handlers expect I/O to be paged in
  RAM[0x1] = 0x32; // Chargen instead of I/O, no BASIC but KERNAL
  memmove( (void*)0x3000, CHARACTER_ROM+8*256, 8*256 ); // "+8*256" to copy the lower-case set that cputhex8 works with
  RAM[0x1] = 0x36; // I/O and KERNAL but no BASIC ( disabled by cc65 anyway)
  CLI(); // Re-enable IRQs

  // Refer the VIC to the in-RAM version of the character set
  VIC.addr = ( ( (uint16_t)CHAR_MATRIX / 1024) << 4 )
           | ( ( (uint16_t)CUSTOM_CHARS / 2048) << 1 )
           ;

  // Replace glyphs $60..$63 inclusive with solid blocks in the background,
  // foreground, background #1 and background #2 colors respectively
  memset( &CUSTOM_CHARS[8*0x60], 0x00, 8 );
  memset( &CUSTOM_CHARS[8*0x61], 0x55, 8 );
  memset( &CUSTOM_CHARS[8*0x62], 0xaa, 8 );
  memset( &CUSTOM_CHARS[8*0x63], 0xff, 8 );

  clrscr();
  textcolor( COLOR_WHITE );
  memset( COLOR_RAM, 8+COLOR_BLUE, 40*25 ); // "8+" enables multi-color as
  // opposed to hi-res on a per-cell basis.  Only colors 0..7 are available
  // because of this though

  // Draw with characters $60..$63 in order to test collision with them
  CHAR_MATRIX[40* 9+17] = 0x60;
  CHAR_MATRIX[40* 9+22] = 0x61;
  CHAR_MATRIX[40*14+17] = 0x62;
  CHAR_MATRIX[40*14+22] = 0x63;
}


void toggle_sprite_priority()
{
  VIC.spr_bg_prio ^= 1 << 0;
}


void move_sprite( dx, dy )
{
  int16_t  new_x = VIC.spr0_x + dx;
  if ( new_x < 0  ||  255 < new_x )
    VIC.spr_hi_x ^= 1 << 0;
  VIC.spr0_x = new_x;
  VIC.spr0_y += dy;
}


int main (void)
{
  init();

  while( true)
  {
    uint16_t  i;
    uint8_t  joy_state = joy_read();
    int8_t  y_axis = JOY_BTN_UP(joy_state) ? -1
                   : JOY_BTN_DOWN(joy_state) ? +1
                   : 0
                   ;
    int8_t  x_axis = JOY_BTN_LEFT(joy_state) ? -1
                   : JOY_BTN_RIGHT(joy_state) ? +1
                   : 0
                   ;
    if ( x_axis || y_axis ) move_sprite( x_axis, y_axis );
    if ( JOY_BTN_FIRE(joy_state) )
      toggle_sprite_priority();

    // Show the state of the sprite to background collision register
    gotoxy( 1, 1 ); cputs("coll: $"); cputhex8( VIC.spr_bg_coll );
    gotoxy( 1, 2 ); cputs("prio: $"); cputhex8( VIC.spr_bg_prio );
    gotoxy( 1, 3 ); cputs("   x: $"); cputc( VIC.spr_hi_x >> 0 & 0x1 ? '1' : '0'); cputhex8( VIC.spr0_x );
    gotoxy( 1, 4 ); cputs("   y: $"); cputhex8( VIC.spr0_y );

    for ( i = 0;  i < 512;  i += 1 );
  }

  return 0;
}

