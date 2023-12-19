
ASM   = 00_nasm.bat
ASMOP = -f obj
LINK  = 00_link.bat
LINKOP= -offset 10000h -mindata 7000h -maxdata 7000h

all: int21_4a.exp

int21_4a.obj: int21_4a.asm
	$(ASM) $(ASMOP) $<

int21_4a.exp: int21_4a.obj
	$(LINK) $(LINKOP) $<

