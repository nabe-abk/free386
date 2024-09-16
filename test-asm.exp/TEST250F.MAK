
ASM   = 00_nasm.bat
ASMOP = -f obj
LINK  = 00_link.bat
LINKOP= -offset 2000h

all: test250f.exp

test250f.obj: test250f.asm
	$(ASM) $(ASMOP) -o $@ -l test250f.lst $<

test250f.exp: test250f.obj
	$(LINK) $(LINKOP) -o $@ $<

