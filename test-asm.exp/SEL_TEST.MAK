
ASM   = 00_nasm.bat
ASMOP = -f obj
LINK  = 00_link.bat
LINKOP= -maxdata 8000h

all: sel_test.exp

sel_test.obj: sel_test.asm
	$(ASM) $(ASMOP) -o $@ $<

sel_test.exp: sel_test.obj
	$(LINK) $(LINKOP) -o $@ $<
