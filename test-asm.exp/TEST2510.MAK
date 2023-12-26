
ASM   = 00_nasm.bat
ASMOP = -f obj
LINK  = 00_link.bat
LINKOP= -offset 2000h

all: test2510.exp

test2510.obj: test2510.asm
	$(ASM) $(ASMOP) -o $@ -l test2510.lst $<

test2510.exp: test2510.obj
	$(LINK) $(LINKOP) -o $@ $<

