/*

PLAN
  - tremolo and other effects by feeding $d41b in to other controls regularly

*/

#include <stdbool.h>
#include <stdint.h>
#include <c64.h>
#include <conio.h>
#include <stdlib.h>


// The 6481 registers are write-only, so a copy of their values must be kept
// for display:
struct __sid  _shadow_SID;
// So that generic code can access registers as a byte array:
uint8_t  *shadow_SID = (uint8_t*)&_shadow_SID;
uint8_t  *real_SID = (uint8_t*)&SID.v1.freq;

typedef struct
{
  uint8_t   offset;       // byte offset from $d400
  uint8_t   bit_position; // of LSB for multi-bit fields
  uint16_t  mask;         // ignored for single bit fields
  enum {
    VOICE_SPECIFIC,
    GENERAL,
  } type;
}
Field;

#define  FIELD( addr, offset, width )  { (uint8_t*)&SID.addr - (uint8_t*)&SID.v1.freq, offset, width, GENERAL }
#define  VS_FIELD( addr, offset, width )  { (uint8_t*)&SID.addr - (uint8_t*)&SID.v1.freq, offset, width, VOICE_SPECIFIC }

Field  voice_freq =   VS_FIELD( v1.freq, 0, 0xffff );
Field  duty_cycle =   VS_FIELD( v1.pw, 0, 0x0fff );
Field  noise =        VS_FIELD( v1.ctrl, 7, 1 );
Field  pulse =        VS_FIELD( v1.ctrl, 6, 1 );
Field  sawtooth =     VS_FIELD( v1.ctrl, 5, 1 );
Field  triangle =     VS_FIELD( v1.ctrl, 4, 1 );
Field  voice_enable = VS_FIELD( v1.ctrl, 3, 1 );
Field  ring_mod =     VS_FIELD( v1.ctrl, 2, 1 );
Field  sync =         VS_FIELD( v1.ctrl, 1, 1 );
Field  gate =         VS_FIELD( v1.ctrl, 0, 1 );
Field  attack =       VS_FIELD( v1.ad, 4, 0xf );
Field  decay =        VS_FIELD( v1.ad, 0, 0xf );
Field  sustain =      VS_FIELD( v1.sr, 4, 0xf );
Field  release =      VS_FIELD( v1.sr, 0, 0xf );
Field  flt_freq =     FIELD( flt_freq, 0, 0xff07 );
Field  flt_strength = FIELD( flt_ctrl, 4, 0xf );
Field  flt_ext =      FIELD( flt_ctrl, 3, 1 );
Field  flt_v1  =      FIELD( flt_ctrl, 2, 1 );
Field  flt_v2  =      FIELD( flt_ctrl, 1, 1 );
Field  flt_v3  =      FIELD( flt_ctrl, 0, 1 );
Field  disable_v3 =   FIELD( amp, 7, 1 );
Field  high_pass =    FIELD( amp, 6, 1 );
Field  band_pass =    FIELD( amp, 5, 1 );
Field  low_pass =     FIELD( amp, 4, 1 );
Field  volume =       FIELD( amp, 0, 0xf );

char     key = 0x00;
bool     showing_keys = true;
uint8_t  voice = 0; // 0, 1 or 2 for voice 1, 2 or 3
Field   *fields[] = {
  &voice_freq,
  &duty_cycle,
  &attack,
  &decay,
  &sustain,
  &release,
  &flt_freq,
  &flt_strength,
  &volume,
};
char *name_of_field[] = {
  "voice frequency ",
  "duty cycle      ",
  "attack          ",
  "decay           ",
  "sustain         ",
  "release         ",
  "filter frequency",
  "filter strength ",
  "master volume   ",
};
uint8_t  selected_field = 0;

uint16_t  ATTACK_DURATION[] = {
  2,
  8,
  16,
  24,
  38,
  56,
  68,
  80,
  100,
  250,
  500,
  800,
  1000,
  3000,
  5000,
  8000,
};
uint16_t  DECAY_DURATION[] = {
  6,
  24,
  48,
  72,
  114,
  168,
  204,
  240,
  300,
  750,
  1500,
  2400,
  3000,
  9000,
  15000,
  24000,
};


void cputuint( uint16_t value)
{
  char  to_s[6];
  utoa( value, to_s, 10);
  cputs( to_s);
}


void  select_field( int8_t direction)
{
  selected_field = ( selected_field + direction + sizeof(fields) / sizeof(fields[0]) ) % ( sizeof(fields) / sizeof(fields[0]) );
}


uint8_t  offset( Field *f)
{
  uint8_t  base = ( f->type == VOICE_SPECIFIC) ? 7*voice : 0;
  return base + f->offset;
}


uint16_t  current( Field *f)
{
  uint8_t  offset = offset( f);

  switch( f->mask)
  {
    case 0xffff:
      return (uint16_t)(shadow_SID[ offset+1]) << 8 | shadow_SID[ offset];

    case 0x0fff:
      return (uint16_t)(shadow_SID[ offset+1] & 0xf) << 8 | shadow_SID[ offset];

    case 0xff07:
      return (uint16_t)(shadow_SID[ offset+1]) << 3 | shadow_SID[ offset] & 0x7;

    default:
      return ( shadow_SID[ offset] >> f->bit_position) & f->mask;
  }
}


void set( Field *f, uint16_t value )
{
  uint8_t  offset = offset( f);

  switch ( f->mask)
  {
    case 0xffff:
      shadow_SID[ offset] = value & 0xff;
      shadow_SID[ offset+1] = value >> 8;
      break;

    case 0x0fff:
      shadow_SID[ offset] = value & 0xff;
      shadow_SID[ offset+1] = value >> 8 & 0xf;
      break;

    case 0xff07:
      shadow_SID[ offset] = value & 0x07;
      shadow_SID[ offset+1] = value >> 3 & 0xff;
      break;

    default:
      shadow_SID[ offset] = shadow_SID[ offset] & ~(f->mask << f->bit_position) | ( value << f->bit_position);
  }
  real_SID[ offset] = shadow_SID[ offset];
  if ( 0xff < f->mask)
    real_SID[ offset+1] = shadow_SID[ offset+1];
}


void adjust( Field* f, int16_t amount )
{
  uint16_t  value = current( f);
  uint16_t  adjusted_mask = ( f->mask != 0xff07) ? f->mask : 0x7ff;
  // Some fields such as the 16-bit wide voice frequency field are so large
  // that adjustments should be made in larger steps:
  switch ( f->mask)
  {
    case 0xffff: amount *= 256; break;
    case 0x0fff: amount *= 16; break;
    case 0xff07: amount *= 8; break;
  }
  set( f, (value + amount) & adjusted_mask );
}


void toggle( Field *f )
{
  uint8_t  offset = offset( f);
  shadow_SID[ offset] ^= ( 1 << f->bit_position);
  real_SID[ offset] = shadow_SID[ offset];
}


void init()
{
  clrscr();
  set(&voice_freq,0x1000);
  set(&noise,1);
  set(&attack, 12 ); // 1 sec
  set(&decay, 10 ); // 1sec5
  set(&sustain, 12 ); // 75%
  set(&release, 10 ); // 1sec5
  set(&volume,15);
}


void render()
{
  uint8_t  row = 0;
  if ( showing_keys)
  {
    cputsxy( 1, ++row, "F1     Show keys");
    cputsxy( 1, ++row, "1..3   Select voice 1, 2 or 3");
    cputsxy( 1, ++row, "n      Toggle Noise waveform");
    cputsxy( 1, ++row, "p      Toggle Pulse waveform");
    cputsxy( 1, ++row, "s      Toggle Sawtooth waveform");
    cputsxy( 1, ++row, "t      Toggle Triangle waveform");
    cputsxy( 1, ++row, "u      Enable/Disable this voice");
    cputsxy( 1, ++row, "m      Toggle Ring modulation");
    cputsxy( 1, ++row, "y      Toggle Synchronisation");
    cputsxy( 1, ++row, "e      Toggle filtering of ext. input");
    cputsxy( 1, ++row, "4..6   Toggle filtering of voice 1..3");
    cputsxy( 1, ++row, "i      Toggle Voice #3 mute");
    cputsxy( 1, ++row, "h      Toggle High-pass filter");
    cputsxy( 1, ++row, "e      Toggle External filter");
    cputsxy( 1, ++row, "b      Toggle Band-pass filter");
    cputsxy( 1, ++row, "l      Toggle Low-pass filter");
    cputsxy( 1, ++row, "g      Gate ( Play)");
    cputsxy( 1, ++row, "r      Release");
    cputsxy( 1, ++row, "lf/rt  select control");
    cputsxy( 1, ++row, "up/dn  inc/dec selected control");
  }
  else {
    uint32_t  system_clock = 985250; // FIXME: Support NTSC clock of 1022730
    uint16_t  frequency = (uint32_t)current(&voice_freq) * (system_clock >> 4) >> (24-4);
    uint8_t   dc = (uint32_t)current(&duty_cycle) * 100 / 4095;
    uint16_t  cutoff_freq = 30 + current(&flt_freq) * (58/2) / (10/2);
    cputsxy( 1, ++row, "$V+00 $"); cputhex16( current(&voice_freq) ); gotoxy( 17, row); cputuint( frequency); cputs("Hz    ");
    cputsxy( 1, ++row, "$V+02 $"); cputhex16( current(&duty_cycle) ); gotoxy( 17, row); cputuint( dc); cputs("%    ");
    cputsxy( 1, ++row, "$V+04 %"); cputc( current(&noise) ?        'n' : '-');
                                   cputc( current(&pulse) ?        'p' : '-');
                                   cputc( current(&sawtooth) ?     's' : '-');
                                   cputc( current(&triangle) ?     't' : '-');
                                   cputc( current(&voice_enable) ? 'd' : '-');
                                   cputc( current(&ring_mod) ?     'r' : '-');
                                   cputc( current(&sync) ?         'S' : '-');
                                   cputc( 'X');
    cputsxy( 1, ++row, "$V+05 $"); cputhex8( shadow_SID[7*voice+5]);
                                   cputsxy( 17, row, "A:"); cputuint(ATTACK_DURATION[ current(&attack)]);
                                   cputs(" D:"); cputuint( DECAY_DURATION[current(&decay)]); cputs(" ms       ");
                                   // A:1-4 chars, D:1-5 chars. min:2, max:9, hence 7 spaces
    cputsxy( 1, ++row, "$V+06 $"); cputhex8( shadow_SID[7*voice+6]);
                                   cputsxy( 17, row, "S:"); cputuint( current(&sustain) * 100 / 15);
                                   cputs("% R:"); cputuint( DECAY_DURATION[current(&release)]); cputs("ms      ");
                                   // S:1-3 chars, R:1-5 chars. min:2, max:8, hence 6 spaces
    cputsxy( 1, ++row, "$d416 $"); cputhex16( current(&flt_freq)); cputsxy( 17, row, "Filter "); cputuint( cutoff_freq); cputs("Hz    ");
    cputsxy( 1, ++row, "$d417 %"); cputs("????");
                                   cputc( current(&flt_ext) ? 'x' : '-');
                                   cputc( current(&flt_v1) ? '1' : '-');
                                   cputc( current(&flt_v2) ? '2' : '-');
                                   cputc( current(&flt_v3) ? '3' : '-');
                                   cputsxy( 17, row, "Strength:"); cputuint( current(&flt_strength)); cputc(' ');
    cputsxy( 1, ++row, "$d418 %"); cputc( current(&disable_v3) ? 'Q' : '-');
                                   cputc( current(&high_pass) ? 'h' : '-');
                                   cputc( current(&band_pass) ? 'b' : '-');
                                   cputc( current(&low_pass) ? 'L' : '-');
                                   cputs("????");
                                   cputs(" Volume:"); cputuint( current(&volume)); cputc(' ');
    cputsxy( 1, ++row, "$d41b $"); cputhex8( SID.noise); cputsxy( 17, row, "Oscillator #3 output");
    cputsxy( 1, ++row, "$d41c $"); cputhex8( SID.read3); cputsxy( 17, row, "Envelope #3 output");
    cputsxy( 1, ++row, "voice "); cputc('1'+voice);
    cputsxy( 1, ++row, "field "); cputs( name_of_field[ selected_field]);
    //cputsxy( 1, ++row, "key:              $"); cputhex8( key);
  }
}


void loop( void)
{
  if ( kbhit())
  {
    switch ( key = cgetc() )
    {
      case CH_F1:         showing_keys ^= true; clrscr(); break;
      case '1':           voice = 0; break; // Select Voice #1
      case '2':           voice = 1; break; // Select Voice #2
      case '3':           voice = 2; break; // Select Voice #3
      case '4':           toggle(&flt_v1); break;
      case '5':           toggle(&flt_v2); break;
      case '6':           toggle(&flt_v3); break;
      case 'n':           toggle(&noise); break;
      case 'p':           toggle(&pulse); break;
      case 's':           toggle(&sawtooth); break;
      case 't':           toggle(&triangle); break;
      case 'u':           toggle(&voice_enable); break;
      case 'm':           toggle(&ring_mod); break;
      case 'y':           toggle(&sync); break;
      case 'e':           toggle(&flt_ext); break;
      case 'i':           toggle(&disable_v3); break;
      case 'h':           toggle(&high_pass); break;
      case 'b':           toggle(&band_pass); break;
      case 'l':           toggle(&low_pass); break;
      case CH_CURS_UP:    adjust( fields[selected_field], +1 ); break;
      case CH_CURS_DOWN:  adjust( fields[selected_field], -1 ); break;
      case CH_CURS_LEFT:  select_field(-1); break;
      case CH_CURS_RIGHT: select_field(+1); break;
      case 'g':           set(&gate, 1); break;
      case 'r':           set(&gate, 0); break;
    }
  }

  render();
}


int main( void)
{
  init();

  while( true)
  {
    loop();
  }

  return 0;
}

/*
SID.v1.freq = 0xffff;
SID.v1.pw = 0x0000;
SID.v1.ctrl = ( 1 << 7)  // Noise
            | ( 0 << 6)  // Pulse
            | ( 0 << 5)  // Sawtooth
            | ( 0 << 4)  // Triangle
            | ( 0 << 3)  // Disable
            | ( 0 << 2)  // Ring modulation
            | ( 0 << 1)  // Sync
            | ( 1 << 0)  // Gate
            ;
SID.amp = ( 0 << 7)  // Disable Voice #3
        | ( 0 << 6)  // Enable High-pass filter
        | ( 0 << 5)  // Enable Band-pass filter
        | ( 0 << 4)  // Enable Low-pass filter
        | ( volume << 0)  // Volume
        ;
SID.flt_freq = 0x0000;
SID.flt_ctrl = ( 0 << 4)  // Intensity
             | ( 0 << 3)  // Filter External
             | ( 0 << 2)  // Filter Voice #3
             | ( 0 << 1)  // Filter Voice #2
             | ( 0 << 0)  // Filter Voice #1
             ;
SID.amp = ( 0 << 7)  // Disable Voice #3
        | ( 0 << 6)  // Enable High-pass filter
        | ( 0 << 5)  // Enable Band-pass filter
        | ( 0 << 4)  // Enable Low-pass filter
        | ( 15 << 0)  // Volume
        ;
*/

