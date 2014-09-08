
.export _asm_init
.import _raster_interrupt_handler
.import _view
.export _scroll_up
.export _scroll_up_left
.export _scroll_left
.export _scroll_down_left
.export _scroll_down
.export _scroll_down_right
.export _scroll_right
.export _scroll_up_right
.export _tile_read_head
.export _write_head
.export _render_tiles_across
.export _render_tiles_down

; Zero-page usage:
chars_to_copy =   $f7 ; Actually chars_to_copy - 1
_tile_read_head = $f8
char_read_head =  $fa
_write_head =     $fc
within_tile_x =   $fe
within_tile_y =   $ff

WORLD_WIDTH_IN_TILES = 32


; -----------------------------------------------------------------------------

irq_vector = $0314

old_handler:
  .byt 0, 0


_asm_init:
  ; Disable interrupts so that the CPU doesn't try to service an interrupt when
  ; the vector is half-changed
  sei

  ; Remember the address of the existing IRQ handler so that it can be chained
  ; to keep the keyboard scanning and jiffy clock working
  lda irq_vector
  sta old_handler
  lda irq_vector+1
  sta old_handler+1

  ; Install the new IRQ handler
  lda #<irq_handler
  sta irq_vector
  lda #>irq_handler
  sta irq_vector+1

  ; Re-enable maskable interrupts
  cli

  rts


irq_handler:

  ; If the IRQ was caused by a CIA rather than the VIC then defer to the old handler
  lda $d019   ; Interrupt status
  and #$01    ; Raster interrupt indicator mask
  bne @interrupted_by_raster

  jmp (old_handler)

@interrupted_by_raster:
  ; Acknowledge the raster interrupt.  Using an "inc" is cheeky.  The LSB of
  ; $d019 that is used to acknowledge the raster interrupt is currently 0.
  ; "inc" will set that bit to 1 as part of counting upwards.  No other bits
  ; will be affected because the bit was previously 0 and therefore no overflow
  ; will occur.
  ;inc $d019
  lda #$ff
  sta $d019

  jsr _raster_interrupt_handler

  ; The main IRQ/BRK handler saved A, X and Y, so restore them:
  pla
  tay
  pla
  tax
  pla

  rti



; "scroll" refers to the direction in which the characters on-screen move.
; Panning *down* involves scrolling *up* ( and revealing a row at the bottom)

_scroll_up:

  ldx #$27
: lda $0428,x
  sta $0400,x
  lda $0450,x
  sta $0428,x
  lda $0478,x
  sta $0450,x
  lda $04a0,x
  sta $0478,x
  lda $04c8,x
  sta $04a0,x
  lda $04f0,x
  sta $04c8,x
  lda $0518,x
  sta $04f0,x
  lda $0540,x
  sta $0518,x
  lda $0568,x
  sta $0540,x
  lda $0590,x
  sta $0568,x
  lda $05b8,x
  sta $0590,x
  lda $05e0,x
  sta $05b8,x
  lda $0608,x
  sta $05e0,x
  lda $0630,x
  sta $0608,x
  lda $0658,x
  sta $0630,x
  lda $0680,x
  sta $0658,x
  lda $06a8,x
  sta $0680,x
  lda $06d0,x
  sta $06a8,x
  lda $06f8,x
  sta $06d0,x
  lda $0720,x
  sta $06f8,x
  lda $0748,x
  sta $0720,x
  lda $0770,x
  sta $0748,x
  lda $0798,x
  sta $0770,x
  lda $07c0,x
  sta $0798,x
  dex
  bmi :+
    jmp :-
: rts


_scroll_up_left:
  ldy #$26
  ldx #$ff
: inx
  lda $0429,x
  sta $0400,x
  lda $0451,x
  sta $0428,x
  lda $0479,x
  sta $0450,x
  lda $04a1,x
  sta $0478,x
  lda $04c9,x
  sta $04a0,x
  lda $04f1,x
  sta $04c8,x
  lda $0519,x
  sta $04f0,x
  lda $0541,x
  sta $0518,x
  lda $0569,x
  sta $0540,x
  lda $0591,x
  sta $0568,x
  lda $05b9,x
  sta $0590,x
  lda $05e1,x
  sta $05b8,x
  lda $0609,x
  sta $05e0,x
  lda $0631,x
  sta $0608,x
  lda $0659,x
  sta $0630,x
  lda $0681,x
  sta $0658,x
  lda $06a9,x
  sta $0680,x
  lda $06d1,x
  sta $06a8,x
  lda $06f9,x
  sta $06d0,x
  lda $0721,x
  sta $06f8,x
  lda $0749,x
  sta $0720,x
  lda $0771,x
  sta $0748,x
  lda $0799,x
  sta $0770,x
  lda $07c1,x
  sta $0798,x
  dey
  bmi :+
    jmp :-
: rts


_scroll_left:

  ; Goes through loop with Y=$27 and Y=1, i.e. 27x
  ldy #$26
  ldx #$ff
: inx
  lda $0401,x
  sta $0400,x
  lda $0429,x
  sta $0428,x
  lda $0451,x
  sta $0450,x
  lda $0479,x
  sta $0478,x
  lda $04a1,x
  sta $04a0,x
  lda $04c9,x
  sta $04c8,x
  lda $04f1,x
  sta $04f0,x
  lda $0519,x
  sta $0518,x
  lda $0541,x
  sta $0540,x
  lda $0569,x
  sta $0568,x
  lda $0591,x
  sta $0590,x
  lda $05b9,x
  sta $05b8,x
  lda $05e1,x
  sta $05e0,x
  lda $0609,x
  sta $0608,x
  lda $0631,x
  sta $0630,x
  lda $0659,x
  sta $0658,x
  lda $0681,x
  sta $0680,x
  lda $06a9,x
  sta $06a8,x
  lda $06d1,x
  sta $06d0,x
  lda $06f9,x
  sta $06f8,x
  lda $0721,x
  sta $0720,x
  lda $0749,x
  sta $0748,x
  lda $0771,x
  sta $0770,x
  lda $0799,x
  sta $0798,x
  lda $07c1,x
  sta $07c0,x
  dey
  bmi :+
    jmp :-
: rts


_scroll_down_left:
  ldy #$26
  ldx #$ff
: inx
  lda $0799,x
  sta $07c0,x
  lda $0771,x
  sta $0798,x
  lda $0749,x
  sta $0770,x
  lda $0721,x
  sta $0748,x
  lda $06f9,x
  sta $0720,x
  lda $06d1,x
  sta $06f8,x
  lda $06a9,x
  sta $06d0,x
  lda $0681,x
  sta $06a8,x
  lda $0659,x
  sta $0680,x
  lda $0631,x
  sta $0658,x
  lda $0609,x
  sta $0630,x
  lda $05e1,x
  sta $0608,x
  lda $05b9,x
  sta $05e0,x
  lda $0591,x
  sta $05b8,x
  lda $0569,x
  sta $0590,x
  lda $0541,x
  sta $0568,x
  lda $0519,x
  sta $0540,x
  lda $04f1,x
  sta $0518,x
  lda $04c9,x
  sta $04f0,x
  lda $04a1,x
  sta $04c8,x
  lda $0479,x
  sta $04a0,x
  lda $0451,x
  sta $0478,x
  lda $0429,x
  sta $0450,x
  lda $0401,x
  sta $0428,x
  dey
  bmi :+
    jmp :-
: rts


_scroll_down:
  ldx #$27
: lda $0798,x
  sta $07c0,x
  lda $0770,x
  sta $0798,x
  lda $0748,x
  sta $0770,x
  lda $0720,x
  sta $0748,x
  lda $06f8,x
  sta $0720,x
  lda $06d0,x
  sta $06f8,x
  lda $06a8,x
  sta $06d0,x
  lda $0680,x
  sta $06a8,x
  lda $0658,x
  sta $0680,x
  lda $0630,x
  sta $0658,x
  lda $0608,x
  sta $0630,x
  lda $05e0,x
  sta $0608,x
  lda $05b8,x
  sta $05e0,x
  lda $0590,x
  sta $05b8,x
  lda $0568,x
  sta $0590,x
  lda $0540,x
  sta $0568,x
  lda $0518,x
  sta $0540,x
  lda $04f0,x
  sta $0518,x
  lda $04c8,x
  sta $04f0,x
  lda $04a0,x
  sta $04c8,x
  lda $0478,x
  sta $04a0,x
  lda $0450,x
  sta $0478,x
  lda $0428,x
  sta $0450,x
  lda $0400,x
  sta $0428,x
  dex
  bmi :+
    jmp :-
: rts


_scroll_down_right:
  ldx #$26
: lda $0798,x
  sta $07c1,x
  lda $0770,x
  sta $0799,x
  lda $0748,x
  sta $0771,x
  lda $0720,x
  sta $0749,x
  lda $06f8,x
  sta $0721,x
  lda $06d0,x
  sta $06f9,x
  lda $06a8,x
  sta $06d1,x
  lda $0680,x
  sta $06a9,x
  lda $0658,x
  sta $0681,x
  lda $0630,x
  sta $0659,x
  lda $0608,x
  sta $0631,x
  lda $05e0,x
  sta $0609,x
  lda $05b8,x
  sta $05e1,x
  lda $0590,x
  sta $05b9,x
  lda $0568,x
  sta $0591,x
  lda $0540,x
  sta $0569,x
  lda $0518,x
  sta $0541,x
  lda $04f0,x
  sta $0519,x
  lda $04c8,x
  sta $04f1,x
  lda $04a0,x
  sta $04c9,x
  lda $0478,x
  sta $04a1,x
  lda $0450,x
  sta $0479,x
  lda $0428,x
  sta $0451,x
  lda $0400,x
  sta $0429,x
  dex
  bmi :+
    jmp :-
: rts


_scroll_right:
  ldx #$26
: lda $07c0,x
  sta $07c1,x
  lda $0798,x
  sta $0799,x
  lda $0770,x
  sta $0771,x
  lda $0748,x
  sta $0749,x
  lda $0720,x
  sta $0721,x
  lda $06f8,x
  sta $06f9,x
  lda $06d0,x
  sta $06d1,x
  lda $06a8,x
  sta $06a9,x
  lda $0680,x
  sta $0681,x
  lda $0658,x
  sta $0659,x
  lda $0630,x
  sta $0631,x
  lda $0608,x
  sta $0609,x
  lda $05e0,x
  sta $05e1,x
  lda $05b8,x
  sta $05b9,x
  lda $0590,x
  sta $0591,x
  lda $0568,x
  sta $0569,x
  lda $0540,x
  sta $0541,x
  lda $0518,x
  sta $0519,x
  lda $04f0,x
  sta $04f1,x
  lda $04c8,x
  sta $04c9,x
  lda $04a0,x
  sta $04a1,x
  lda $0478,x
  sta $0479,x
  lda $0450,x
  sta $0451,x
  lda $0428,x
  sta $0429,x
  lda $0400,x
  sta $0401,x
  dex
  bmi :+
    jmp :-
: rts


_scroll_up_right:
  ldx #$26
: lda $07c0,x
  sta $0799,x
  lda $0798,x
  sta $0771,x
  lda $0770,x
  sta $0749,x
  lda $0748,x
  sta $0721,x
  lda $0720,x
  sta $06f9,x
  lda $06f8,x
  sta $06d1,x
  lda $06d0,x
  sta $06a9,x
  lda $06a8,x
  sta $0681,x
  lda $0680,x
  sta $0659,x
  lda $0658,x
  sta $0631,x
  lda $0630,x
  sta $0609,x
  lda $0608,x
  sta $05e1,x
  lda $05e0,x
  sta $05b9,x
  lda $05b8,x
  sta $0591,x
  lda $0590,x
  sta $0569,x
  lda $0568,x
  sta $0541,x
  lda $0540,x
  sta $0519,x
  lda $0518,x
  sta $04f1,x
  lda $04f0,x
  sta $04c9,x
  lda $04c8,x
  sta $04a1,x
  lda $04a0,x
  sta $0479,x
  lda $0478,x
  sta $0451,x
  lda $0450,x
  sta $0429,x
  lda $0428,x
  sta $0401,x
  dex
  bmi :+
    jmp :-
: rts


; -----------------------------------------------------------------------------

; When coarse_scroll happens, will need to fill in EITHER:
;   - LEFT col OR right col OR neither
;   - FIRST row OR last row OR neither

; As far as the filler is concerned, they're all the same.  Only need to know:
;   - the 16-bit address in char matrix where we're filling
;   - whether to move across a cell or down a cell next
;   - How many cells to fill ( opportunity to fill only 24 if both top/bottom and left/right exposed)
;   - The cell address (x,y) within the map
;   - Whether to inc x or y in the cell address

; In practice there should be separate code for horizontal and vertical stripes
; because the horizontal code can use INC to move the write_head rather than
; ADC and won't cross pages so no overflow detection is required.

; Given world(x,y), Tile cell address is world(x,y) / 4
; Find tile_type with lookup within tile matrix
; char cell address within tile is world(x,y) % 4
; Within block, bx and by

; Core loop ( common case) is 0..3 copying whole strip ( horz or vert) from tile type to screen


; char_read_head is a pointer to a row of characters within a tile pattern


TILE_PATTERNS_BASE = $4000

; Either the first or the last row of characters on screen has been revealed
; and should be filled in with tiles from the map.
;
; Render:
;  - First ( partial) tile ( unless only whole tiles will be rendered)
;  - Middle ( whole) tiles
;  - Last ( partial) tile
;
; When within_tile.x is:
;  0: 10 whole stripes of tiles should be copied
;     ,-Characters to copy from first tile
;     |   ,-Characters to copy as whole tiles
;     |   |     ,-Characters to copy from last tile
;  1: 3 + 4*9 + 1
;  2: 2 + 4*9 + 2
;  3: 1 + 4*9 + 3

_render_tiles_across:

  ; within_tile_y = ( view.y + row_on_screen) & 0x3
  clc
  adc _view+1
  and #$03
  ; sta within_tile_y
  asl
  asl
  sta @offset_within_tile+1

  ; Work out how many whole tiles should be copied
  ; If within_tile_x is 0 then 10 whole tiles should be copied, otherwise 9
  ldx #10
  ; within_tile_x = view.x & 0x3
  lda _view+0  ; view.x
  and #$03
  sta within_tile_x
  ; Add within_tile_x to @offset_within_tile ( only for the first partial tile)
  ora @offset_within_tile+1
  sta @offset_within_tile+1
  beq :+
  ; partial_copies_required = within_tile_x isnt 0
  dex
  ; Work out how many ( character) cell columns of the first tile should be copied
  ; chars_to_copy = 4 - within_tile_x
  ; No need to set up shared-use core as a subroutine since it was done on last
  ; invocation ( and is the default in in object code) even if the previous
  ; invocation didn't involve partial copies of tiles
  lda #3  ; 4 - 1.  "- 1" because shared-use core counts down to 0 inclusive
  sec
  sbc within_tile_x
  jsr @copy_partial
  ; write_head += 4 - within_tile_x
  lda _write_head
  clc
  adc chars_to_copy
  adc #1
  sta _write_head  ; No overflow possible since _write_head will always be $400..427 or $3c0..3e7
:
  ; Set up shared-use core as core rather than subroutine
  lda #$ea  ; NOP
  sta @rts_or_nop
  ; Rip out within_tile_x for @offset_within_tile for subsequent tiles
  lda @offset_within_tile+1
  and #$fc
  sta @offset_within_tile+1
  ; Set "chars_to_copy - 1" to 3 for copying whole tiles in the core
  lda #3

  ; The following code is alternately used as a subroutine and a core depending
  ; on whether the instruction at @rts_or_nop is an RTS or NOP.  This is the
  ; entry point when used as a subroutine.  A is chars_to_copy - 1, i.e. "3" to
  ; copy 4 characters
@copy_partial:
  sta chars_to_copy

  ; While 0 < X, loop back here to render another slice of the tile
@each_tile:

  ; A < *tile_read_head  # i.e. tile_pattern_id
  ldy #$00
  lda (_tile_read_head),y

  ; Work out the address of the tile pattern and more specifically the
  ; address of a particular row of characters within tile pattern

  ; char_read_head = TILE_PATTERNS_BASE
  ;                + 16 * tile_pattern_id   # 16 bytes per tile pattern
  ;                +  4 * within_tile.y     # 4 bytes per row of chars
  ; The "+ 4 * within_tile.y" will never cross a page boundary because tile patterns are 16-byte aligned

  ; Multiply tile_pattern_id by 16:

  ; A is the rolling value that will end up in LO char_read_head

  ; Seed HI char_read_head with HI TILE_PATTERNS_BASE, pre divided by 16 so
  ; that when it's multiplied by 16 it comes back to normal.  NOTE:
  ; TILE_PATTERNS_BASE must have LO nybble of HI byte all zero, i.e 4K aligned
  ; for this to work
  ldy #(>TILE_PATTERNS_BASE / 16)
  sty char_read_head+1

  asl
  rol char_read_head+1  ; the old MSB of A goes to LSB of HI char_read_head
  asl
  rol char_read_head+1
  ; A has been <<2, so the 2 LSB are zero and we can | within_tile.y so that the two remaining ASLs multiply it by 4
  ;ora within_tile_y  ; now combined with within_tile_x for first ( partial) tile at @offset_within_tile
  asl
  rol char_read_head+1
  asl
  rol char_read_head+1
@offset_within_tile:
  ora #$00 ; Self-modifying
  sta char_read_head

  ; Copy a row of characters from the tile pattern to the screen
  ldy chars_to_copy
@copy_char:
  lda (char_read_head),y
  sta (_write_head),y
  dey
  bpl @copy_char

  ; tile_read_head += 1
  inc _tile_read_head
  bne *+2+2 ; Skip the INC, no need for label
  inc _tile_read_head+1

@rts_or_nop:
  rts  ; Overwritten with RTS or NOP so that this snippet can be used to render the partial tiles on the far left and right without requiring a ( slow) JSR in the core

  ; _write_head += 4
  lda _write_head
  clc
  adc #$04
  sta _write_head  ; No overflow possible since _write_head will always be $400..427 or $3c0..3e7

  dex
  bne @each_tile

  ; Configure the core as a subroutine
  ldy #$60 ; RTS
  sty @rts_or_nop

  ; If within_tile_x is 0 then the last tile was copied by the core and this
  ; section should be skipped
  txa  ; is 0
  cmp within_tile_x
  beq :+
    ; Otherwise, work out how many characters from the last tile ( if any) should
    ; be copied.  within_tile_x is 1..3.  If it's 1 then 1 character from the
    ; last tile should be copied, so:
    ;   chars_to_copy = within_tile.x
    ; But subtract an extra 1 because the core counts down to 0 inclusive:
    ; A = within_tile_x - 1
    lda within_tile_x
    sec
    sbc #$01
    jsr @copy_partial
: rts


; -----------------------------------------------------------------------------

  ; Cases for within_tile_y:
  ;   0: 0 + 4*6 + 1
  ;   1: 3 + 4*5 + 2
  ;   2: 2 + 4*5 + 3
  ;   3: 1 + 4*6 + 0
  ; rows_from_first_tile_to_copy = 4 - within_tile_y.  render only if within_tile_y isnt 0
  ; rows_to_copy_from_final_tile = (1+ within_tile_y) & 0x3.  render only if > 0

_whole_tiles:  ; Use within_tile_y as index
  .byt 6, 5, 5, 6

; @param  A  column_on_screen
;
_render_tiles_down:

  ; Macro structure:
  ;   - Core is used as a subroutine to render partially visible tiles at the
  ;     top and bottom and *also* as a loop by self-modifying the instruction
  ;     at the end to be either RTS or DEX

  ; within_tile_x = ( view.x + column_on_screen) & 0x3
  clc
  adc _view+0
  and #$03
  sta @offset_within_tile+1

  lda _write_head
  sta @write_head+1
  lda _write_head+1
  sta @write_head+2

  ; Work out how many whole tiles should be copied
  ; If within_tile_y is 0 or 3 then 6 whole tiles should be copied, otherwise 5
  ldx #6
  ; within_tile_y = view.y & 0x3
  lda _view+1  ; view.y
  and #$03
  sta within_tile_y
  ; Add within_tile_y to @offset_within_tile ( only for the first partial tile)
  asl
  asl
  ora @offset_within_tile+1
  sta @offset_within_tile+1
  lda within_tile_y
  ; If within_tile_y is 0 then the first tile is fully rather than partially copied
  beq :+
    ; partial_copies_required = within_tile_x isnt 0
    ldx #9
    ; Work out how many ( character) cell rows of the first tile should be copied
    ; chars_to_copy = 4 - within_tile_y
    ; No need to set up shared-use core as a subroutine since it was done on last
    ; invocation ( and is the default in in object code) even if the previous
    ; invocation didn't involve partial copies of tiles
    lda #4
    sec
    sbc within_tile_y
    jsr @copy_partial
:
  ; Set up shared-use core as core rather than subroutine
  lda #$ca  ; DEX
  sta @rts_or_dex
  ; Rip out within_tile_y for @offset_within_tile for subsequent tiles
  lda @offset_within_tile+1
  and #$f3
  sta @offset_within_tile+1
  ; Select the number of whole tiles to render
  ldy within_tile_y
  lda _whole_tiles,y
  tax
  ; Set the number of characters to copy from each whole tile
  lda #4

  ; The following code is alternately used as a subroutine and a core depending
  ; on whether the instruction at @rts_or_dex is an RTS or NOP.  This is the
  ; entry point when used as a subroutine.  A is chars_to_copy - 1, i.e. "3" to
  ; copy 4 characters
@copy_partial:
  asl
  asl
  sta @compare+1

  ; While 0 < X, loop back here to render another strip of the tile
@each_tile:

  ; A < *tile_read_head  # i.e. tile_pattern_id
  ldy #$00
  lda (_tile_read_head),y

  ; Work out the address of the tile pattern and more specifically the
  ; address of a particular column of characters within the tile pattern

  ; char_read_head = TILE_PATTERNS_BASE
  ;                + 16 * tile_pattern_id   # 16 bytes per tile pattern
  ;                +  4 * within_tile.y     # 4 bytes per row of chars
  ; The "+ 4 * within_tile.y" will never cross a page boundary because tile patterns are 16-byte aligned

  ; Multiply tile_pattern_id by 16:

  ; A is the rolling value that will end up in LO char_read_head

  ; Seed HI char_read_head with HI TILE_PATTERNS_BASE, pre divided by 16 so
  ; that when it's multiplied by 16 it comes back to normal.  NOTE:
  ; TILE_PATTERNS_BASE must have LO nybble of HI byte all zero, i.e 4K aligned
  ; for this to work
  ldy #(>TILE_PATTERNS_BASE / 16)
  sty char_read_head+1

  asl
  rol char_read_head+1  ; the old MSB of A goes to LSB of HI char_read_head
  asl
  rol char_read_head+1
  asl
  rol char_read_head+1
  asl
  rol char_read_head+1
@offset_within_tile:
  ora #$00 ; Self-modifying
  sta char_read_head

  ; Copy a vertical stripe of characters from the tile pattern to the screen
  ldy #0

@copy_char:
  lda (char_read_head),y
@write_head:
  sta $0100 ; Self-modifying
  ; Move write_head to the next screen row
  lda @write_head+1
  clc
  adc #40
  sta @write_head+1
  bcc :+
    inc @write_head+2
:
  iny
  iny
  iny
  iny
@compare:
  cpy #$00 ; Self-modifying
  bne @copy_char

  ; tile_read_head += WORLD_WIDTH_IN_TILES
  lda _tile_read_head
  clc
  adc #WORLD_WIDTH_IN_TILES
  sta _tile_read_head
  bcc *+2+2 ; Skip the INC, no need for label
    inc _tile_read_head+1

@rts_or_dex:
  ; This instruction is overwritten with either RTS or DEX so that this snippet
  ; can be used to render the partial tiles at the top and bottom without
  ; requiring a ( slow) JSR in the loop that renders whole tiles
  rts
  ;dex
  bne @each_tile

  ; Configure the core as a subroutine
  ldy #$60 ; RTS
  sty @rts_or_dex

  ; rows_to_copy_from_final_tile = (1+ within_tile_y) & 0x3.  render only if > 0
  ldy within_tile_y
  iny
  tya
  and #$03
  beq :+
    jsr @copy_partial
: rts

