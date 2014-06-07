
#include <stdbool.h>
#include <stdint.h>
#include <c64.h>

#include "asm.h"
#include "joystick.h"


#define CHAR_MATRIX  ((unsigned char*)0x0400)


struct
{
  uint8_t  x;
  uint8_t  y;
}
view;


// A mapping function that provides the character than should appear at the
// specified co-ordinates
uint8_t character_at( row, column )
{
  int8_t  x = view.x + column;
  int8_t  y = view.y + row;
  //return ( (view.y+ row) & 15 ) << 4 | ( (view.x+ column) & 15);
  return x << 2 ^ x * y << 3 ^ y << 1;
}


void init()
{
  uint8_t  row, column;

  VIC.bordercolor = COLOR_BLACK;
  VIC.bgcolor0 = COLOR_BLACK;
  /*
  VIC.ctrl1 = ( 0 << 7) // ninth bit of raster line
            | ( 0 << 6) // 0: extended background mode disabled
            | ( 0 << 5) // 0: text mode rather than graphics
            | ( 1 << 4) // 1: do not blank the whole display
            | ( 0 << 3) // 0: 24-row mode for fine vertical scrolling
            | ( 0 << 0) // 0..7: fine vertical scrolling
            ;
  VIC.ctrl2 = ( 0 << 5) // 0: do not reset the VIC-II
            | ( 0 << 4) // 1: multi-color mode
            | ( 0 << 3) // 0: 38-column mode for fine horizontal scrolling
            | ( 0 << 0) // 0..7: fine horizontal scrolling
            ;
            */
  view.x = 0;
  view.y = 0;
  for ( row = 0;  row < 25;  row += 1 )
  {
    uint8_t  *line = (uint8_t*)( 0x400+ 40* row );
    for ( column = 0;  column < 40;  column += 1 )
      line[ column] = character_at( row, column);
  }
}


// @param  horizontally  -1, 0 or +1, where -1 will move the view LEFT
// @param  vertically    -1, 0 or +1, where -1 will move the view UP
//
void pan( int8_t horizontally, int8_t vertically )
{
  uint8_t  row, column;

  view.x += horizontally;
  view.y += vertically;

  coarse_scroll( 40* -vertically+ -horizontally );

  if ( horizontally )
  {
    // When the view pans LEFT, the characters on-screen are moved RIGHT so
    // newly revealed characters are on the LEFT
    column = -1 == horizontally ? 0 : 39;
    for ( row = 0;  row < 25;  ++row )
    {
      CHAR_MATRIX[ 40* row+ column ] = character_at( row, column );
    }
  }
  if ( vertically )
  {
    row = -1 == vertically ? 0 : 24;
    for ( column = 0;  column < 40;  ++column )
    {
      CHAR_MATRIX[ 40* row+ column ] = character_at( row, column );
    }
  }
}


int main (void)
{
  init();

  while( true)
  {
    uint8_t  joy_state = joy_read();
    int8_t  y_axis = JOY_BTN_UP(joy_state) ? -1
                   : JOY_BTN_DOWN(joy_state) ? +1
                   : 0
                   ;
    int8_t  x_axis = JOY_BTN_LEFT(joy_state) ? -1
                   : JOY_BTN_RIGHT(joy_state) ? +1
                   : 0
                   ;
    if ( x_axis || y_axis ) pan( x_axis, y_axis );
  }

  return 0;
}

