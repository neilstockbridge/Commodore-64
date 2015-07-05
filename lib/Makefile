
# Define PROJECT, LIBDIR and PARTS then:
#  include $(LIBDIR)/Makefile

CFLAGS += -O -I$(LIBDIR)

OUTDIR ?= /tmp/C64

.c.o:
	cl65 $(CFLAGS) $(LDFLAGS) -c $< -o $@

.S.o:
	ca65 $(AFLAGS) $< -o $@

.SILENT:
all: $(PARTS)
	cl65 $(LDFLAGS) -o $(OUTDIR)/$(PROJECT).prg $(PARTS)

clean:
	rm -f *.o *.map $(OUTDIR)/$(PROJECT).prg

