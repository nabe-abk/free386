
ASM   = 00_nasm.bat
ASMOP = -f pharlap
LINK  = 00_link.bat
LINKOP=

all: vsync_fm.exp

vsync_fm.obj: vsyn_cnt.asm
	$(ASM) $(ASMOP) -o $@ -d TOWNS vsyn_cnt.asm 

vsync_fm.exp: vsync_fm.obj
	$(LINK) $(LINKOP) vsync_fm.obj
