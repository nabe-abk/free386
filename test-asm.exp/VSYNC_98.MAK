
ASM   = 00nasm.bat
ASMOP = -f pharlap
LINK  = 00linker.bat

all: vsync_98.exp

vsync_98.obj: vsyn_cnt.asm
	$(ASM) $(ASMOP) -o vsync_98.obj -d PC98 vsyn_cnt.asm

vsync_98.exp: vsync_98.obj
	$(LINK) vsync_98.obj
