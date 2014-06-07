
# 8-way coarse scrolling demo

Demonstrates:

  + Reading the joystick
  + Using assembly routines from C
  + An assembly routine for 8-directional coarse scrolling


`main.c` allows using the joystick to pan a "view" around a synthetic "world".  The contents of the world are dictated by `character_at( row, column)`, which provides the character that should be rendered at the specified row and column on the screen ( taking the `view: x, y` in to account).

  + `main()` polls the joystick.  If the joystick is held in any of the eight directions then `pan()` is invoked
  + `pan()` updates `view`, invokes the assembly routine `coarse_scroll()` and then fills in the edge or edges that are exposed using `character_at()`
  + `asm.h` stitches the C and assembly together.  `__fastcall__` means that the parameter is passed in the `A` register rather than the ( software) stack

