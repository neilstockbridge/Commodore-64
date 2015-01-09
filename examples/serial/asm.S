
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
  jmp CHKOUT


; A:data
_ser_putc:

  jmp CHROUT


; A:LF#, X:DEV#, Y:SA
SETLFS = $ffba

; A:length, X,Y:LO,HI ptr to filename ( or serial params)
SETNAM = $ffbd

; X:LF#
CHKOUT = $ffc9

; No params
OPEN = $ffc0

; A:data
CHROUT = $ffd2

