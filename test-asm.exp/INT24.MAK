
ASM   = .\00nasm.bat
ASMOP = -f pharlap
LINK  = .\00linker.bat
LINKOP= -maxdata 1000h

all: int24_b.exp int24_c.exp


int24_b.obj: int24.asm
	$(ASM) $(ASMOP) -o $@ -d DRIVE_B int24.asm

int24_b.exp: int24_b.obj
	$(LINK) $(LINKOP) int24_b.obj


int24_c.obj: int24.asm
	$(ASM) $(ASMOP) -o $@ -d DRIVE_C int24.asm

int24_c.exp: int24_c.obj
	$(LINK) $(LINKOP) int24_c.obj
