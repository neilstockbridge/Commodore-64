
#include "joystick.h"
#include <c64.h>


uint8_t joy_read()
{
  return CIA1.pra;
}

