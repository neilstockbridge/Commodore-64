
#include <stdbool.h>
#include <stdint.h>
#include <conio.h>
#include <c64.h>


void cputbin8( uint8_t value )
{
  uint8_t  m;
  for ( m = 0x80;  m != 0x00;  m >>= 1 )
    cputc( value & m ? '1' : '0');
}


void render()
{
  cputsxy( 1, 1, "$d011:%"); cputbin8( VIC.ctrl1);
  cputsxy( 1, 2, "$d016:%"); cputbin8( VIC.ctrl2);
}


void scroll_vertically( int8_t delta )
{
  VIC.ctrl1 = VIC.ctrl1 & 0xf8 | (VIC.ctrl1 + delta) & 0x7;
}


void scroll_horizontally( int8_t delta )
{
  VIC.ctrl2 = VIC.ctrl2 & 0xf8 | (VIC.ctrl2 + delta) & 0x7;
}


void init( void)
{
  clrscr();
  render();
}


void loop( void)
{
  if ( kbhit())
  {
    switch ( cgetc() )
    {
      case 'v': VIC.ctrl1 ^= (1 << 3); break;
      case 'h': VIC.ctrl2 ^= (1 << 3); break;
      case 'w': scroll_vertically(-1); break;
      case 's': scroll_vertically(+1); break;
      case 'a': scroll_horizontally(-1); break;
      case 'd': scroll_horizontally(+1); break;
    }
    render();
  }
}


int main( void)
{
  init();

  while( true)
  {
    loop();
  }

  return 0;
}

