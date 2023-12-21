
ASM   = 00_nasm.bat
ASMOP = -f obj
LINK  = 00_link.bat
LINKOP=

all: chk_f386.exp

chk_f386.obj: chk_f386.asm
	$(ASM) $(ASMOP) -o $@ $<

chk_f386.exp: chk_f386.obj
	$(LINK) $(LINKOP) -o $@ $<
