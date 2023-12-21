
ASM   = 00_nasm.bat
ASMOP = -f obj
LINK  = 00_link.bat
LINKOP= -maxdata 1000h

all: int24h.exp

int24h.obj: int24h.asm
	$(ASM) $(ASMOP) -o $@ $<

int24h.exp: int24h.obj
	$(LINK) $(LINKOP) -o $@ $<

