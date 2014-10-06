
#include <stdbool.h>
#include <stdint.h>
#include <c64.h>
#include <string.h> // for memset
#include <conio.h>


#define  CHAR_MATRIX      ((uint8_t*) 0x0400)
#define  SHAPE_FOR_SPRITE ((uint8_t*) 0x07f8)
#define  TEST_SHAPE       ((uint8_t*) 0x4000 - 64)


void paint( row, column, code )
{
  CHAR_MATRIX[ 40* row+ column] = code;
}


void toggle_number_of_rows()
{
  VIC.ctrl1 ^= ( 1 << 3 );
}

void toggle_number_of_columns()
{
  VIC.ctrl2 ^= ( 1 << 3 );
}


void scroll_vertically( int8_t delta )
{
  VIC.ctrl1 = VIC.ctrl1 & 0xf8 | (VIC.ctrl1 + delta) & 0x7;
}

void scroll_horizontally( int8_t delta )
{
  VIC.ctrl2 = VIC.ctrl2 & 0xf8 | (VIC.ctrl2 + delta) & 0x7;
}


void move_sprite_on_y( int8_t amount )
{
  VIC.spr0_y += amount;
}

void move_sprite_on_x( int8_t amount )
{
  int16_t  new_x = VIC.spr0_x + amount;
  if ( new_x < 0  ||  255 < new_x )
    VIC.spr_hi_x ^= ( 1 << 0 );
  VIC.spr0_x = new_x;
}


uint8_t  cell_x;
uint8_t  cell_y;


void render()
{
  uint16_t  pixel_x;
  uint8_t   pixel_y;
  uint8_t   new_cell_x;
  uint8_t   new_cell_y;

  // Work out the pixel-granularity co-ordinates within the character matrix
  // ( rather than the visible display) of the pixel immediately to the
  // lower-right of the sprite
  #define  SPRITE_WIDTH  24
  #define  SPRITE_HEIGHT  21
  #define  FINE_SCRL_Y  ( VIC.ctrl1 & 0x7 )
  #define  FINE_SCRL_X  ( VIC.ctrl2 & 0x7 )
  #define  NORM_FINE_Y  3  // The value of FINE_SCRL_Y 
  pixel_x = ( ((VIC.spr_hi_x >> 0 & 0x1)<< 8) + VIC.spr0_x) - 24 + SPRITE_WIDTH - FINE_SCRL_X;
  pixel_y = VIC.spr0_y - 50 + SPRITE_HEIGHT + NORM_FINE_Y - FINE_SCRL_Y;

  // Show the parameters to the formula
  cputsxy( 1, 21, "fine: $"); cputhex8( FINE_SCRL_X); cputc(','); cputhex8( FINE_SCRL_Y);
  cputsxy( 1, 22, "sprt: $"); cputhex8( VIC.spr0_x); cputc(','); cputhex8( VIC.spr0_y);
  cputsxy( 1, 23, "cell: $"); cputhex8( pixel_x >> 3); cputc('.'); cputhex8( pixel_x & 0x7); cputc(','); cputhex8( pixel_y >> 3); cputc('.'); cputhex8( pixel_y & 0x7);

  // Work out the new cell x,y to the lower-right of the sprite
  new_cell_x = pixel_x >> 3;
  new_cell_y = pixel_y >> 3;
  // If it has changed..
  if ( new_cell_x != cell_x  ||  new_cell_y != cell_y )
  {
    // Blank out the old indicator
    paint( cell_y, cell_x, 0x20 );
    // Paint in the new one
    paint( new_cell_y, new_cell_x, 0xa0 );
    // ..and remember the cell co-ordinates
    cell_x = new_cell_x;
    cell_y = new_cell_y;
  }
}


void init()
{
  // Start with the sprite in the top-left corner
  VIC.spr0_x = 24;
  VIC.spr0_y = 50;
  // Make the sprite shape solid
  memset( TEST_SHAPE, 0xff, 24/3*21 );
  SHAPE_FOR_SPRITE[0] = (uint16_t)TEST_SHAPE >> 6;
  // Pink
  VIC.spr0_color = COLOR_LIGHTRED;
  // ..and visible
  VIC.spr_ena = ( 1 << 0 );

  clrscr();
  render();
}


void loop( void)
{
  char  key;

  if ( kbhit())
  {
    switch ( key = cgetc() )
    {
      case 'r': toggle_number_of_rows(); break;
      case 'c': toggle_number_of_columns(); break;
      case 'w': scroll_vertically( -1 ); break;
      case 's': scroll_vertically( +1 ); break;
      case 'a': scroll_horizontally( -1 ); break;
      case 'd': scroll_horizontally( +1 ); break;
      case CH_CURS_UP:    move_sprite_on_y( -1 ); break;
      case CH_CURS_DOWN:  move_sprite_on_y( +1 ); break;
      case CH_CURS_LEFT:  move_sprite_on_x( -1 ); break;
      case CH_CURS_RIGHT: move_sprite_on_x( +1 ); break;
    }
    render();
  }
}


int main ( void)
{
  init();

  while( true)
  {
    loop();
  }

  return 0;
}

