
ASM   = 00nasm.bat
ASMOP = -f pharlap
LINK  = 00linker.bat

all: vsync_fm.exp

vsync_fm.obj: vsyn_cnt.asm
	$(ASM) $(ASMOP) -o vsync_fm.obj -d TOWNS vsyn_cnt.asm 

vsync_fm.exp: vsync_fm.obj
	$(LINK) vsync_fm.obj
