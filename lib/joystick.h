
#ifndef __JOYSTICK_H
#define __JOYSTICK_H


#include <stdint.h>


/* Intended to be like cc65 joystick support but only support Joystick#2 on the C64 */

#define  JOY_UP     0
#define  JOY_DOWN   1
#define  JOY_LEFT   2
#define  JOY_RIGHT  3
#define  JOY_FIRE   4

#define  JOY_BTN_UP(v)     ( ((v) & (1 << JOY_UP)) == 0 )
#define  JOY_BTN_DOWN(v)   ( ((v) & (1 << JOY_DOWN)) == 0 )
#define  JOY_BTN_LEFT(v)   ( ((v) & (1 << JOY_LEFT)) == 0 )
#define  JOY_BTN_RIGHT(v)  ( ((v) & (1 << JOY_RIGHT)) == 0 )
#define  JOY_BTN_FIRE(v)   ( ((v) & (1 << JOY_FIRE)) == 0 )


// Provides the current state of Joystick #2
extern  uint8_t  joy_read();


#endif

