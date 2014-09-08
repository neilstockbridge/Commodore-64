
# Define PROJECT, LIBDIR and PARTS then:
#  include $(LIBDIR)/Makefile

CFLAGS += -O -I$(LIBDIR)

.c.o:
	cl65 $(CFLAGS) $(LDFLAGS) -c $< -o $@

.S.o:
	ca65 $(AFLAGS) $< -o $@

.SILENT:
all: $(PARTS)
	cl65 $(LDFLAGS) -o /tmp/$(PROJECT).prg $(PARTS)

clean:
	rm -f *.o *.map /tmp/$(PROJECT).prg

