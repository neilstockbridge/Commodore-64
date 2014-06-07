
PROJECT = 8-way-scroll

PARTS = main.o asm.o

CFLAGS = -O -Wall

.c.o:
	cl65 -c $< -o $@

.S.o:
	ca65 $< -o $@

.SILENT:
all: $(PARTS)
	cl65 -o /tmp/$(PROJECT).prg $(PARTS)

clean:
	rm -f *.o *.map /tmp/$(PROJECT).prg

