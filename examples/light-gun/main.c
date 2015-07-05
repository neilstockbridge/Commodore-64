/*

Findings:

  - A 1531 mouse updates SID.ad1 and SID.ad2 with POTX and POTY ( bits 1
    through 6 only).  The left mouse button presses FIRE and RMB UP

  - VICE seems to update SID.ad1 and SID.ad2 regardless of whether paddles have
    been selected or not

  - It was necessary to configure CIA#1 Port A as INPUT in order to read
    switches on devices in port 2.  Maybe the keyscan routine is configuring as
    OUTPUT ( the default) when scanning the keyboard and then INPUT when done,
    which doesn't happen with CIA#1 interrupts disabled

  - Holding the Left mouse button down on a 1531 in port 1 causes VIC.strobe_x
    to fluctuate, perhaps not surprising given how light guns signal to the VIC
    that electrons have been detected

*/

#include <stdbool.h>
#include <stdint.h>
#include <c64.h>
#include <conio.h>


void render()
{
  uint8_t  row = 1;
  cputsxy( 1, row++, "$d013 strobe_x: $"); cputhex8( VIC.strobe_x);
  cputsxy( 1, row++, "$d014 strobe_y: $"); cputhex8( VIC.strobe_y);
  cputsxy( 1, row++, "$d419 SID.ad1:  $"); cputhex8( SID.ad1);
  cputsxy( 1, row++, "$d41a SID.ad2:  $"); cputhex8( SID.ad2);
  cputsxy( 1, row++, "$dc00 CIA1.pra: $"); cputhex8( CIA1.pra);
  cputsxy( 1, row++, "$dc01 CIA1.prb: $"); cputhex8( CIA1.prb);
  cputsxy( 1, row++, "$dc02 CIA1.ddra: $"); cputhex8( CIA1.ddra);
  cputsxy( 1, row++, "$dc03 CIA1.ddrb: $"); cputhex8( CIA1.ddrb);
}


void init()
{
  clrscr();

  // Disable CIA#1 interrupts
  CIA1.icr = 0x7f;

  // Configure to read paddles on port #2
  CIA1.pra = 0x7f;

  // Configure CIA#1 Port A as INPUT so that buttons on device in port 2 can be
  // read.
  CIA1.ddra = 0x00;
}


void loop( void)
{
  render();
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

