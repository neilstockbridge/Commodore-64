
.export _asm_init
.import _raster_interrupt_handler

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
  bne interrupted_by_raster

  jmp (old_handler)

interrupted_by_raster:
  ; Acknowledge the raster interrupt.  Using an "inc" is cheeky.  The LSB of
  ; $d019 that is used to acknowledge the raster interrupt is currently 0.
  ; "inc" will set that bit to 1 as part of counting upwards.  No other bits
  ; will be affected because the bit was previously 0 and therefore no overflow
  ; will occur.
  inc $d019

  jsr _raster_interrupt_handler

  ; The main IRQ/BRK handler saved A, X and Y, so restore them:
  pla
  tay
  pla
  tax
  pla

  rti

