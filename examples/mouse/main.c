
#include <stdbool.h>
#include <stdint.h>
#include <c64.h>


#define  CHAR_MATRIX  ((uint8_t*)0x0400)

#define  SCREEN_WIDTH   40
#define  SCREEN_HEIGHT  25


struct
{
  int8_t  x, y;
}
mouse_cursor = { 0, 0 };


static void  clamp( int8_t *value, int8_t min, int8_t max )
{
  if ( *value < min)
    *value = min;
  if ( max < *value )
    *value = max;
}


#define  remove_mouse_cursor  toggle_mouse_cursor
#define  render_mouse_cursor  toggle_mouse_cursor
static void  toggle_mouse_cursor()
{
  // Toggle the character under the house cursor between reverse and normal
  // video
  CHAR_MATRIX[ SCREEN_WIDTH*mouse_cursor.y + mouse_cursor.x ] += 0x80;
}


static int8_t  movement( uint8_t xm64, uint8_t prev_xm64 )
{
  int8_t  m = xm64 - prev_xm64;
  if ( m <= -32)
    m = 64 + m;
  else if ( 32 <= m)
    m = 64 - m;
  return m;
}


static void  poll_mouse()
{
  static uint8_t  prev_xm64 = 0; // X position modulo 64
  static uint8_t  prev_ym64 = 0;
  // How to detect if x_mod64 has wrapped around or not.  There is no
  // bulletproof method since x_mod64 might go from 0x00 to 0x3f between two
  // polling periods and although it is *likely* that it was decreasing, it is
  // not certain.  It might also have wrapped twice and there is no way to
  // tell, so we just have to *assume* that the polling ( and update in the
  // mouse - ~2 kHz in the 1531) is fast enough that the mouse cannot move fast
  // enough to cause these problems
  uint8_t  xm64 = ( SID.ad1 >> 1) & 0x3f;
  uint8_t  ym64 = ( SID.ad2 >> 1) & 0x3f;
  // If 32 < abs( x_mod64 - prev_x_mod64) then this is either a quick movement
  // or ( more likely) a wraparound
  int8_t  dx = movement( xm64, prev_xm64 );
  int8_t  dy = movement( ym64, prev_ym64 );
  if ( dx != 0  ||  dy != 0 )
  {
    remove_mouse_cursor();

    mouse_cursor.x += dx;
    // NOTE: "-=" below because POTY values *decrease* as the 1531 is pulled
    // towards the user
    mouse_cursor.y -= dy;
    clamp( &mouse_cursor.x, 0, SCREEN_WIDTH - 1 );
    clamp( &mouse_cursor.y, 0, SCREEN_HEIGHT - 1 );

    render_mouse_cursor();

    prev_xm64 = xm64;
    prev_ym64 = ym64;
  }

  {
    bool  lmb_is_down = ! ( CIA1.prb & 0x10);
    bool  rmb_is_down = ! ( CIA1.prb & 0x01);
    VIC.bordercolor = lmb_is_down | ( rmb_is_down << 1);
  }
}


static void  init( void)
{
  // Disable CIA#1 interrupts because otherwise the keyboard scanning routine
  // will overwrite CIA1.pra and interpret mouse button clicks as key presses
  CIA1.icr = 0x7f;

  // Configure to read paddle on port #2
  CIA1.pra = ( 1 << 0)  // Select keyboard column #0.  0:Select, 1:Ignore
           | ( 1 << 1)  // Select keyboard column #1
           | ( 1 << 2)  // Select keyboard column #2
           | ( 1 << 3)  // Select keyboard column #3
           | ( 1 << 4)  // Select keyboard column #4
           | ( 1 << 5)  // Select keyboard column #5
           | ( 1 << 6)  // Select keyboard column #6 and the paddles in port 1
           | ( 1 << 7)  // Select keyboard column #7 and the paddles in port 2
           // Coming from ignorance but this smells like a bug in VICE: Mouse
           // emulation ( 1351 in port 1) updates POTX and POTY even when
           // POTA[XY] are not routed to POT[XY]
           ;

  render_mouse_cursor();
}


static void loop( void)
{
  poll_mouse();
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

