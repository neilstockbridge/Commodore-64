
.export _coarse_scroll


; @param  A  The offset: +1 to shift the display right, -39 to shift it up-right, etc.
;
; Some cells at the edges are copied when they need not be, but to avoid this
; would make the code more complex, larger and possibly slower anyway
;
_coarse_scroll:

  ; The character matrix is 40 columns across and 25 rows down, with
  ; 1000 = 40 * 25 cells.  This routine shifts the contents of those cells in
  ; one of eight directions:
  ;
  ;  A is +1: Characters shifted RIGHT across the screen, although confusingly
  ;           the view will appear to pan LEFT
  ;  A is +40: Characters shifted DOWN the screen
  ;  A is +41: Characters shifted both down AND right
  ;  A is +39, -1, -39, -40 or -41: Similarly

  ; This routine is a bit like memmove except single-purpose for performance

  ; The core consists of three whole-page copies and one partial-page copy

  ; If A is positive then X must *decrement* otherwise it must *increment* in
  ; order to avoid destroying the memory that should be moved.
  ; The two paths of this routine are similar but different.
  cmp #0
  bpl @copy_to_higher_address

  ; Cell contents will be copied to lower addresses, such as from $0401 to
  ; $0400.  A must be inverted and is used to adjust the LDA instructions
  ; rather than the STA instructions
  sta @invert+1   ; +1 to adjust the operand rather than the opcode!
  lda #0
  sec
@invert:
  sbc #$00

  ; Adjust the "lda" instructions.  The "sta" instructions will be adjusted
  ; instead in the other path
  sta @load0+1
  sta @load1+1
  sta @load2+1
  sta @load3+1
  sta @lower_subtract+1

  ; 40*25 is the number of cells on screen and 256*3 the number of cells copied
  ; by the whole-page-copy code below
  ; Work out how many bytes should be copied for the partial page copy
  lda # 40*25 - 256*3
  sec
@lower_subtract:
  sbc #$00
  sta @partial_copy_size+1

  ; The partial-page copy.
  ; The "lda" instruction is adjusted so that when the "offset" parameter is
  ; -1, the core will load from $0701+X and store to $0700+X
@load3:
  lda $0700,x
  sta $0700,x
  inx
@partial_copy_size:
  cpx #$00
  bne @load3

  ; The three whole page copies:
  ldx #0
@load0:
  lda $0400,x
  sta $0400,x
@load1:
  lda $0500,x
  sta $0500,x
@load2:
  lda $0600,x
  sta $0600,x
  inx
  bne @load0

  rts

@copy_to_higher_address:
  ; @store is either: +1, +39, +40 or +41 relative to @load
  sta @store0+1
  sta @store1+1
  sta @store2+1
  sta @store3+1
  sta @subtract+1

  lda # 40*25 - 256*3 - 1
  sec
@subtract:
  sbc #$00

  ; The only reason the last ( non-256-byte section is done first is so that
  ; the result of the subtraction need not be saved or self-modified
  tax
@loop1:
  lda $0700,x
@store3:
  sta $0700,x
  dex
  cpx #$ff
  bne @loop1

  ldx #$ff
@loop0:
  lda $0400,x
@store0:
  sta $0400,x
  lda $0500,x
@store1:
  sta $0500,x
  lda $0600,x
@store2:
  sta $0600,x
  dex
  cpx #$ff
  bne @loop0

  rts

