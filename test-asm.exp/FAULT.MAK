
ASM   = 00_nasm.bat
ASMOP = -f obj
LINK  = 00_link.bat
LINKOP= -offset 2000h -maxdata 8000h

all: fault.exp

fault.obj: fault.asm
	$(ASM) $(ASMOP) -o $@ $<

fault.exp: fault.obj
	$(LINK) $(LINKOP) -o $@ $<
