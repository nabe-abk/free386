#


ASM  = 386asm
CC   = free386 d:\hc386\bin\hcd386p
CSW  = -off Floating_point

;LINK = run386 -nocrt d:\hc386\bin\386linkp
LINK = hc386

all: get_dt.exp

mt_seg.obj: mt_seg.asm
	$(ASM) mt_seg.asm

get_dt.obj: get_dt.c
	$(CC) get_dt.c $(CSW)

get_dt.exp: get_dt.obj mt_seg.obj
	$(LINK) get_dt.obj mt_seg.obj
