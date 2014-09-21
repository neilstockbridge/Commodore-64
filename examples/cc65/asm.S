
.export _function_in_asm
.export _zp_ptr

; Zero-page usage:
_zp_ptr =         $fc


; -----------------------------------------------------------------------------

_function_in_asm:
  tay
  lda (_zp_ptr),y
  clc
  adc #1
  sta (_zp_ptr),y
  rts

; -----------------------------------------------------------------------------

