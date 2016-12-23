#


ASM  = 386asm
CC   = run386 -nocrt d:\hc386\bin\hcd386p
CSW  = -off Floating_point

all: dump_mem.exp


# LINK = run386 -nocrt d:\hc386\bin\386linkp
LINK = hc386

mt_seg.obj: mt_seg.asm
	$(ASM) mt_seg.asm

dump_mem.obj: dump_mem.c
	$(CC) dump_mem.c $(CSW)

dump_mem.exp: dump_mem.obj mt_seg.obj
	$(LINK) dump_mem.obj mt_seg.obj
