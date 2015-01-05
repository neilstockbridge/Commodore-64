
#include <stdbool.h>
#include <stdint.h>
#include <string.h> // for memset
#include <c64.h>
#include <conio.h>  // for cput*


#define  CHAR_MATRIX      ((uint8_t*) 0x0400)
#define  SHAPE_FOR_SPRITE ((uint8_t*) 0x07f8)
#define  TEST_SHAPE       ((uint8_t*) 0x4000 - 64)

#define  SPRITE_WIDTH   24
#define  SPRITE_HEIGHT  21

// This is the lowest Sprite Y ordinate for which the top row of pixels of the
// sprite are still visible
#define  SPRITE_Y_TOP   50
#define  SPRITE_X_LEFT  24

#define  MIN_SOLID_CODE  (0x80+' ')


int8_t  to_surface; // of ground
int8_t  to_ceiling;
int8_t  to_wall_on_left;
int8_t  to_wall_on_right;


void place( code, column, row)
{
  CHAR_MATRIX[ 40* row+ column] = code;
}

void paint( color, column, row )
{
  COLOR_RAM[ 40*row + column] = color;
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


void render()
{
  uint16_t  left;
  uint8_t   top;
  uint8_t   center_column;
  uint8_t   row_above;
  uint8_t   row_below;
  uint16_t  below_left_ofs;
  uint16_t  above_left_ofs;

  // Work out the pixel-granularity co-ordinates within the character matrix
  // ( rather than the visible display) of the pixel in the top-left hand
  // corner of the sprite
  #define  FINE_SCRL_Y  ( VIC.ctrl1 & 0x7 )
  #define  FINE_SCRL_X  ( VIC.ctrl2 & 0x7 )
  #define  NORM_FINE_Y  3
  left = ( ((VIC.spr_hi_x >> 0 & 0x1)<< 8) + VIC.spr0_x) - SPRITE_X_LEFT - FINE_SCRL_X;
  top = VIC.spr0_y - SPRITE_Y_TOP + NORM_FINE_Y - FINE_SCRL_Y;

  // Show the parameters to the formula
  cputsxy( 1, 21, "fine: $"); cputhex8( FINE_SCRL_X); cputc(','); cputhex8( FINE_SCRL_Y);
  cputsxy( 1, 22, "sprt: $"); cputhex8( VIC.spr0_x); cputc(','); cputhex8( VIC.spr0_y);
  cputsxy( 1, 23, "cell: $"); cputhex8( left >> 3); cputc('.'); cputhex8( left & 0x7); cputc(','); cputhex8( top >> 3); cputc('.'); cputhex8( top & 0x7);

  memset( COLOR_RAM, COLOR_GREEN, 40*20);
  // Find the row of cells within the character matrix immediately below the
  // "feet" of the sprite
  row_above = top - 1 >> 3;
  // ..and the row immediately above the "head" of the sprite
  row_below = top + SPRITE_HEIGHT >> 3;
  center_column = left + SPRITE_WIDTH/2 >> 3;

  // Show the character matrix cells that will be considered for collision
  below_left_ofs = 40*row_below + center_column - 1;
  above_left_ofs = 40*row_above + center_column - 1;

  // Cells painted LIGHT BLUE are considered as the ceiling for collision
  // ( cuts a jump short)
  paint( COLOR_LIGHTBLUE, center_column-1, row_above );
  paint( COLOR_LIGHTBLUE, center_column,   row_above );
  paint( COLOR_LIGHTBLUE, center_column+1, row_above );
  // Cells painted YELLOW are considered as the ground for collision ( arrests
  // a fall)
  paint( COLOR_YELLOW, center_column-1, row_below );
  paint( COLOR_YELLOW, center_column,   row_below );
  paint( COLOR_YELLOW, center_column+1, row_below );
  // Cells painted PINK are considered as walls for collision ( prevents
  // further movement in to the wall).  Note that the sprite is allowed to
  // overlap with the wall slightly because the sprite is allowed to fall
  // overlapped with the wall.  It's allowed to fall overlapped with the wall
  // because the feet of a character are not the full width of the sprite so
  // the actor would appear to be hovering in the air just prior to falling
  // otherwise ( cf. Creatures).
  // The alternative would be to have the actor move through the air while
  // falling such that the shortest drop in the game nevertheless produced
  // enough horizontal movement to get the actor clear of the wall ( cf.
  // Dizzy).  It would be jarring to allow a fall overlapping the wall but to
  // prevent the actor moving back to overlap the wall again having moved away.
  paint( COLOR_ORANGE, center_column - 1, row_below - 1 );
  paint( COLOR_ORANGE, center_column + 1, row_below - 1 );
  // In theory, "row_below - 1" and " - 2" should be checked to prevent
  // sideways movement too although the cycles can be saved if the map contains
  // no crawlspaces 1 or 2 cells in height
  to_surface = MIN_SOLID_CODE <= CHAR_MATRIX[ below_left_ofs] ||
               MIN_SOLID_CODE <= CHAR_MATRIX[ below_left_ofs + 1]  ||
               MIN_SOLID_CODE <= CHAR_MATRIX[ below_left_ofs + 2]
    ? top + SPRITE_HEIGHT - ( row_below << 3) : -1;

  to_ceiling = MIN_SOLID_CODE <= CHAR_MATRIX[ above_left_ofs] ||
               MIN_SOLID_CODE <= CHAR_MATRIX[ above_left_ofs + 1]  ||
               MIN_SOLID_CODE <= CHAR_MATRIX[ above_left_ofs + 2]
    ? ( row_above + 1 << 3) - top : -1;

  to_wall_on_left = MIN_SOLID_CODE <= CHAR_MATRIX[ below_left_ofs - 40 ]
    ? ( center_column << 3) - ( left + SPRITE_WIDTH/2 - 8 + 1 ) : -1;

  to_wall_on_right = MIN_SOLID_CODE <= CHAR_MATRIX[ below_left_ofs - 40 + 2 ]
    ? ( left + SPRITE_WIDTH/2 + 8 ) - ( center_column + 1 << 3) : -1;

  cputsxy( 20, 21, "to_surf: $"); cputhex8( to_surface);
  cputsxy( 20, 22, "to_wall: $"); cputhex8( to_wall_on_left); cputc(','); cputhex8( to_wall_on_right);
  cputsxy( 20, 23, "to_ceil: $"); cputhex8( to_ceiling);
}


void init()
{
  // Start with the sprite close to the top-left corner ( but not too close
  // otherwise the color highlighting will interfere with the SID!)
  VIC.spr0_x = SPRITE_X_LEFT + 8;
  VIC.spr0_y = SPRITE_Y_TOP + 8;
  // Make the sprite shape solid
  memset( TEST_SHAPE, 0xff, SPRITE_WIDTH/8*SPRITE_HEIGHT );
  SHAPE_FOR_SPRITE[0] = (uint16_t)TEST_SHAPE >> 6;
  // Pink
  VIC.spr0_color = COLOR_LIGHTRED;
  // ..and visible
  VIC.spr_ena = ( 1 << 0 );

  // Fill the screen with chequerboard glyphs intended to denote free space but
  // which still show the color highlighting
  memset( CHAR_MATRIX, 0x66, 40*20);

  // Make a box of solid glyphs to aid with visualisation of collision with the
  // ground, walls and ceiling
  {
    int  i;
    for ( i = 0; i < 8; i += 1)
    {
      place( MIN_SOLID_CODE, 4,     4+i   );
      place( MIN_SOLID_CODE, 4+8-1, 4+i   );
      place( MIN_SOLID_CODE, 4+i,   4     );
      place( MIN_SOLID_CODE, 4+i,   4+8-1 );
    }
  }

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

