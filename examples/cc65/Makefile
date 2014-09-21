
PROJECT = cc65

PARTS = main.o  asm.o  gfx.o

LDFLAGS = -C linker.cfg

CFLAGS += -O

.c.o:
	cl65 $(CFLAGS) $(LDFLAGS) -c $< -o $@

.S.o:
	ca65 $(AFLAGS) $< -o $@

.SILENT:
all: $(PARTS)
	cl65 $(LDFLAGS) -o /tmp/$(PROJECT).prg $(PARTS)

gfx.o: charset.bin

clean:
	rm -f *.o *.map /tmp/$(PROJECT).prg

