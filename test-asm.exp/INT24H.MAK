
ASM   = .\00nasm.bat
ASMOP = -f pharlap
LINK  = .\00linker.bat
LINKOP= -maxdata 1000h

all: int24h_b.exp int24h_c.exp


int24h_b.obj: int24h.asm
	$(ASM) $(ASMOP) -o $@ -d DRIVE_B int24h.asm

int24h_b.exp: int24h_b.obj
	$(LINK) $(LINKOP) int24h_b.obj


int24h_c.obj: int24h.asm
	$(ASM) $(ASMOP) -o $@ -d DRIVE_C int24h.asm

int24h_c.exp: int24h_c.obj
	$(LINK) $(LINKOP) int24h_c.obj
