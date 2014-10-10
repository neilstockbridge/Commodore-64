
# Jumping

Demonstrates a technique for jumping and falling in a platform game.

The Y position of an object is stored in a signed 8-bit variable that represents the sub-pixel position of the object relative to its current Y ordinate on screen.  The LO nybble keeps track of the sub-pixel position, the HI nybble the relative pixel position ( supports movement up to 7 whole pixels in either direction per frame).  If the HI nybble represents -4 then the object will move 4 pixels up the screen this frame and the fractional part of the position in the LO nybble will remain.

