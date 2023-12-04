
ASM   = 00_nasm.bat
ASMOP = -f pharlap
LINK  = 00_link.bat
LINKOP=

all: vsync_98.exp

vsync_98.obj: vsyn_cnt.asm
	$(ASM) $(ASMOP) -o $@ -d PC98 vsyn_cnt.asm

vsync_98.exp: vsync_98.obj
	$(LINK) $(LINKOP) vsync_98.obj
