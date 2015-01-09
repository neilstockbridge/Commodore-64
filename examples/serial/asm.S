
.export _ser_init
.export _ser_putc


; See http://103.11.126.234/programming/Commodore-64/RS-232.html for a
; description of these params.  10: 2400 baud, 8 data bits, 1 STOP bit
ser_params:
  .byt 10, 0, 0, 0


; No params
_ser_init:

  lda #1  ; LF#
  ldx #2  ; DEV#
  ldy #0
  jsr SETLFS

  lda #4
  ldx #<ser_params
  ldy #>ser_params
  jsr SETNAM

  jsr OPEN

  ldx #1
  jsr CHKOUT

  rts


; A:data
_ser_putc:

  jmp CHROUT


; A:LF#, X:DEV#, Y:SA
SETLFS:
  jmp $ffba


; A:length, X,Y:LO,HI ptr to filename ( or serial params)
SETNAM:
  jmp $ffbd


; X:LF#
CHKOUT:
  jmp $ffc9


; No params
OPEN:
  jmp $ffc0


; A:data
CHROUT:
  jmp $ffd2

