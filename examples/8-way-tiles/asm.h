
#ifndef __ASM_H
#define __ASM_H


// write_head is a pointer to the first cell in the character matrix that
// should receive characters from exposed tiles
extern uint8_t *write_head;
#pragma zpsym("write_head");

extern uint8_t *tile_read_head;
#pragma zpsym("tile_read_head");


extern void asm_init( void);

extern void  scroll_up( void);
extern void  scroll_up_left( void);
extern void  scroll_left( void);
extern void  scroll_down_left( void);
extern void  scroll_down( void);
extern void  scroll_down_right( void);
extern void  scroll_right( void);
extern void  scroll_up_right( void);

extern void __fastcall__  render_tiles_across( uint8_t row_on_screen );
extern void __fastcall__  render_tiles_down( uint8_t column_on_screen );


#endif

