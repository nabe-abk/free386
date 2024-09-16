
ASM   = 00_nasm.bat
ASMOP = -f obj
LINK  = 00_link.bat
LINKOP= -offset 1e00h -maxdata 2100h

all: fault.exp

fault.obj: fault.asm
	$(ASM) $(ASMOP) -o $@ $<

fault.exp: fault.obj
	$(LINK) $(LINKOP) -o $@ $<
