
# Sprite to background collision demo

An example that demonstrates:

  + Moving a sprite with the joystick
  + Sprite to background collision and priority
  + Making minor alterations to a copy of the ROM character set
  + Linking graphics

The sprite is divided in to four quadrants with these colors for the pixels:

    %00 %01

    %10 %11

Four characters are shown close to the middle of the screen that are solid blocks drawn in each possible pixel color for multi-color characters.  The state of the sprite to background collision register and sprite to background priority registers are shown.

Move the sprite with a joystick in port 2 and change its background priority with the fire button.

