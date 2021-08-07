#


ASM  = 386asm
# CC   = run386 -nocrt d:\hc386\bin\hcd386p
CC   = d:\hc386\bin\hcd386
CSW  = -off Floating_point

all: dump_mem.exp


# LINK = run386 -nocrt d:\hc386\bin\386linkp
LINK = 386link

mt_seg.obj: mt_seg.asm
	$(ASM) mt_seg.asm

dump_mem.obj: dump_mem.c
	$(CC) dump_mem.c $(CSW)

dump_mem.exp: dump_mem.obj mt_seg.obj
	$(LINK) dump_mem.obj mt_seg.obj -LIB d:\hc386\small\hce.lib,d:\hc386\small\t_os.lib
