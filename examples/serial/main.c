
#include <stdbool.h>
#include <unistd.h> // for sleep()
#include <conio.h>  // for cputc()

#include "asm.h"


void main()
{
  ser_init();

  while ( true)
  {
    ser_putc('a');
    cputc('.');
    sleep(1);
  }
}

