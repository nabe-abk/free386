
ASM   = 00_nasm.bat
ASMOP = -f obj
LINK  = 00_link.bat
LINKOP= -offset 1000h

all: vsync_98.exp vsync_fm.exp

vsync_98.obj: vsyn_cnt.asm
	$(ASM) $(ASMOP) -o $@ -d PC98 $<

vsync_98.exp: vsync_98.obj
	$(LINK) $(LINKOP) -o $@ $<

vsync_fm.obj: vsyn_cnt.asm
	$(ASM) $(ASMOP) -o $@ -d TOWNS $<

vsync_fm.exp: vsync_fm.obj
	$(LINK) $(LINKOP) -o $@ $<
