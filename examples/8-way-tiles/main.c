
#include <stdbool.h>
#include <stdint.h>
#include <string.h>
#include <c64.h>

#include "joystick.h"
#include "asm.h"


#define _RASTER_DEBUG


#define CHAR_MATRIX  ((uint8_t*)0x0400)

#define  TILE_PATTERN            ((uint8_t*) 0x4000) // Array 0..255 of Matrix 0..3 0..3 of char codes
#define  TILE_PATTERN_WIDTH        4
#define  LOG2_TILE_PATTERN_WIDTH   2  // TILE_PATTERN_WIDTH is 4 ( characters across)
#define  LOG2_TILE_PATTERN_HEIGHT  2  // TILE_PATTERN_HEIGHT is 4 ( characters across)
#define  LOG2_TILE_PATTERN_SIZE    4  // Tile patterns are 4 x 4 = 16 characters
#define  TILE_WITHIN_WORLD       ((uint8_t*) 0x5000) // Matrix of 32x16 tile_pattern_ids ( approx 3x3 screens)
#define  WORLD_WIDTH_IN_TILES      32
#define  LOG2_WORLD_WIDTH_IN_TILES  5
#define  WORLD_HEIGHT_IN_TILES     16


typedef struct
{
  uint8_t  x;
  uint8_t  y;
}
Vector;


Vector  view = { 0, 0 };

// View panning instructions ( from the joystick)
int8_t  dx = 0;
int8_t  dy = 0;



void init()
{
  asm_init();

  VIC.imr = 0x01; // Enable "raster compare" interrupts
  VIC.ctrl1 &= 0x7f; // Set the 9th bit of the raster compare register to 0
  VIC.rasterline = 250; // The beginning of the bottom border by experiment with PAL version

  // Disable CIA#1 interrupts
  CIA1.icr = 0x7f;

  // Fill the tiles
  {
    int i,j;
    for ( i = 0; i < 256; i ++)
    {
      for(j=0;j<16;j++)
      TILE_PATTERN[ (i << LOG2_TILE_PATTERN_SIZE) + j] = i;
    }
  }
  // And the world
  {
    int x,y;
    for (x=0;x<WORLD_WIDTH_IN_TILES;x++)
    for (y=0;y<WORLD_HEIGHT_IN_TILES;y++)
    TILE_WITHIN_WORLD[ WORLD_WIDTH_IN_TILES*y +x] = WORLD_WIDTH_IN_TILES*y +x;
  }
}


// @param  dx  -1, 0 or +1, where -1 will move the view LEFT
// @param  dy    -1, 0 or +1, where -1 will move the view UP
//
void pan( int8_t dx, int8_t dy )
{
  uint8_t  row_on_screen;
  uint8_t  column_on_screen;
  Vector   tile_within_world;

  // It should not be possible to pan off the edge of the world
  if ( dx < 0  &&  0 == view.x ) dx = 0;
  if ( 0 < dx  &&  WORLD_WIDTH_IN_TILES*4-40 == view.x ) dx = 0;
  if ( dy < 0  &&  0 == view.y ) dy = 0;
  if ( 0 < dy  &&  WORLD_HEIGHT_IN_TILES*4-25 == view.y ) dy = 0;

  if ( 0 == dx  &&  0 == dy) return;

  view.x += dx;
  view.y += dy;

  // The border should be red to show how long the scrolling takes
  #ifdef _RASTER_DEBUG
  VIC.bordercolor = COLOR_RED;
  #endif

  switch (dy)
  {
  case -1:
    switch(dx)
    {
    case -1: scroll_down_right(); break;
    case  0: scroll_down(); break;
    case +1: scroll_down_left(); break;
    }
    break;
  case 0:
    switch(dx)
    {
    case -1: scroll_right(); break;
    case +1: scroll_left(); break;
    }
    break;
  case +1:
    switch(dx)
    {
    case -1: scroll_up_right(); break;
    case  0: scroll_up(); break;
    case +1: scroll_up_left(); break;
    }
    break;
  }

  // The border should be cyan to show how long the edge filling takes
  #ifdef _RASTER_DEBUG
  VIC.bordercolor = COLOR_CYAN;
  #endif

  // If the character matrix was scrolled horizontally..
  if ( dx )
  {
    // When the view pans LEFT, the characters on-screen are moved RIGHT so
    // newly revealed characters are on the LEFT

    // Render the newly revealed left or right -most column
    column_on_screen = -1 == dx ? 0 : 39;

    // Work out the address (x,y) of the tile cell within the world
    tile_within_world.y = view.y >> LOG2_TILE_PATTERN_HEIGHT;
    tile_within_world.x = ( view.x +column_on_screen) >> LOG2_TILE_PATTERN_WIDTH;
    tile_read_head = TILE_WITHIN_WORLD+ ( tile_within_world.y << LOG2_WORLD_WIDTH_IN_TILES)+ tile_within_world.x;
    write_head = CHAR_MATRIX + column_on_screen;
    render_tiles_down( column_on_screen );
  }
  // If the character matrix was scrolled vertically..
  if ( dy )
  {
    // Render the newly revealed top or bottom row
    row_on_screen = -1 == dy ? 0 : 24;
    write_head = (0 == row_on_screen) ? CHAR_MATRIX : CHAR_MATRIX + 40* 24;

    // Work out the address (x,y) of the tile cell within the world
    tile_within_world.y = ( view.y + row_on_screen) >> LOG2_TILE_PATTERN_WIDTH;
    tile_within_world.x = view.x >> LOG2_TILE_PATTERN_HEIGHT;
    tile_read_head = TILE_WITHIN_WORLD+ ( tile_within_world.y << LOG2_WORLD_WIDTH_IN_TILES)+ tile_within_world.x;
    render_tiles_across( row_on_screen );
  }
}


void raster_interrupt_handler( void)
{
  // The border should be white when the raster interrupt handler is entered
  #ifdef _RASTER_DEBUG
  VIC.bordercolor = COLOR_WHITE;
  #endif

  if ( dx || dy ) pan( dx, dy );

  // These must be set to zero in case the raster inetrrupt handler takes so
  // long that it is re-entered immediately upon exit, meaning that the main
  // loop does not get to run
  dx = 0;
  dy = 0;

  // The border should be black once the raster interrupt handler has finished
  #ifdef _RASTER_DEBUG
  VIC.bordercolor = COLOR_BLACK;
  #endif
}


int main (void)
{
  init();

  while( true)
  {
    uint8_t  joy_state = joy_read();
    dy = JOY_BTN_UP(joy_state) ? -1
       : JOY_BTN_DOWN(joy_state) ? +1
       : 0
       ;
    dx = JOY_BTN_LEFT(joy_state) ? -1
       : JOY_BTN_RIGHT(joy_state) ? +1
       : 0
       ;
  }

  return 0;
}

