
ASM   = 00nasm.bat
ASMOP = -f pharlap
LINK  = 00linker.bat

all: chk_f386.exp

chk_f386.obj: chk_f386.asm
	$(ASM) $(ASMOP) chk_f386.asm

chk_f386.exp: chk_f386.obj
	$(LINK) chk_f386.obj
