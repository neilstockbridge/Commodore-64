
#include <stdbool.h>
#include <stdint.h>
#include <c64.h>
#include <string.h> // for memset

#include "asm.h"
#include "joystick.h"


#define _RASTER_DEBUG


#define  DISABLE  0
#define  ENABLE   1

#define  SHAPE_FOR_SPRITE ((uint8_t*) 0x07f8)
#define  TEST_SHAPE       ((uint8_t*) 0x4000 - 64)

#define  SPRITE_WIDTH    24
#define  SPRITE_HEIGHT   21
#define  SCREEN_WIDTH   320
#define  SCREEN_HEIGHT  200
// This is the lowest Sprite Y ordinate for which the top row of pixels of the
// sprite are still visible
#define  SPRITE_Y_TOP   50
#define  SPRITE_X_LEFT  24
// The Sprite Y ordinate at which the sprite will be "standing" on the lower
// border
#define  GROUND_Y  ( SPRITE_Y_TOP + SCREEN_HEIGHT - SPRITE_HEIGHT )


// Y ordinates increase towards the bottom of the screen yet the values are
// inverted here to match the notion of altitude increasing as it moves further
// from sea level
#define  ACCELERATION        -3  // sub-pixels per vertical retrace
#define  TERMINAL_VELOCITY  -72  // sub-pixels per vertical retrace
#define  JUMP_VELOCITY       72

volatile int8_t  speed = 0;  // in sub-pixels per vertical retrace
volatile int8_t  sub_pixel_y = 0;

uint8_t  joy_state = 0;


bool on_the_ground()
{
  return GROUND_Y <= VIC.spr0_y;
}


void init()
{
  // The sprite should begin in the middle of the screen
  VIC.spr0_x = SPRITE_X_LEFT + SCREEN_WIDTH/2 - SPRITE_WIDTH/2;
  VIC.spr0_y = SPRITE_Y_TOP + SCREEN_HEIGHT/2 - SPRITE_HEIGHT/2;
  // Make the sprite shape solid
  memset( TEST_SHAPE, 0xff, SPRITE_WIDTH/3*SPRITE_HEIGHT );
  SHAPE_FOR_SPRITE[0] = (uint16_t)TEST_SHAPE / 64; // 64 bytes per shape
  // ..pink
  VIC.spr0_color = COLOR_LIGHTRED;
  // ..and visible
  VIC.spr_ena = ( ENABLE << 0 );

  asm_init();

  // Enable "raster compare" interrupts
  VIC.imr = ( DISABLE << 3) // Light pen interrupt enable
          | ( DISABLE << 2) // Sprite-to-sprite collision interrupt enable
          | ( DISABLE << 1) // Sprite-to-background collision interrupt enable
          | ( ENABLE << 0) // "raster line compare" interrupt enable
          ;
  VIC.ctrl1 &= 0x7f; // Set the 9th bit of the raster compare register to 0
  VIC.rasterline = 250; // The beginning of the bottom border by experiment with PAL version

  // Disable CIA#1 interrupts
  CIA1.icr = 0x7f;
}


void move_left()
{
  if ( VIC.spr0_x < 2)
    VIC.spr_hi_x ^= ( 1 << 0 );
  VIC.spr0_x -= 2;
}


void move_right()
{
  if ( 254 <= VIC.spr0_x )
    VIC.spr_hi_x ^= ( 1 << 0 );
  VIC.spr0_x += 2;
}


void animate()
{
  sub_pixel_y += speed;
  #define  SUB_PIXELS  16
  #define  FAST
  #ifdef SLOW
  while ( sub_pixel_y < -SUB_PIXELS)
  {
    sub_pixel_y += SUB_PIXELS;
    VIC.spr0_y += 1;
  }
  while ( SUB_PIXELS < sub_pixel_y)
  {
    sub_pixel_y -= SUB_PIXELS;
    VIC.spr0_y -= 1;
  }
  #else
  if ( SUB_PIXELS <= sub_pixel_y)
  {
    VIC.spr0_y -= sub_pixel_y >> 4;
    sub_pixel_y &= 0xf;
  }
  if ( sub_pixel_y <= -SUB_PIXELS)
  {
    VIC.spr0_y += -sub_pixel_y >> 4;
    sub_pixel_y = -( -sub_pixel_y & 0xf);
  }
  #endif
  // If the object has hit the ground..
  if ( on_the_ground()  &&  speed < 0 )
  {
    // Because this code is capable of moving multiple pixels per frame,
    // sometimes the object will sink in to the ground, hence:
    VIC.spr0_y = GROUND_Y;
    sub_pixel_y = 0;

    #define BOUNCE
    #ifdef BOUNCE
    if ( -SUB_PIXELS < speed)
      speed = 0;
    else
      speed = -speed/2;
    #else
    speed = 0;
    #endif
  }

  // Speed should increase only if not standing on ground and not reached terminal
  // velocity
  if ( !on_the_ground()  &&  TERMINAL_VELOCITY < speed)
    speed += ACCELERATION;

  if ( JOY_BTN_LEFT(joy_state) )
    move_left();

  if ( JOY_BTN_RIGHT(joy_state) )
    move_right();
}


void jump()
{
  // The player should not be able to jump unless there is solid ground
  // underfoot
  if ( on_the_ground() )
  {
    sub_pixel_y = 0;
    speed = JUMP_VELOCITY;
  }
}


void raster_interrupt_handler()
{
  #ifdef _RASTER_DEBUG
  // Change the border color to white so it's easy to get an idea of how many
  // cycles the interrupt handler uses
  VIC.bordercolor = 1;
  #endif

  animate();

  #ifdef _RASTER_DEBUG
  VIC.bordercolor = 0;
  #endif
}


void loop( void)
{
  joy_state = joy_read();

  if ( JOY_BTN_UP(joy_state) )
    jump();
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

