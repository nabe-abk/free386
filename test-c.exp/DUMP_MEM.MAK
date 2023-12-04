#

CC   = 00_cc.bat
COPT = -off Floating_point
LINK = 00_link.bat

all: dump_mem.exp

dump_mem.obj: dump_mem.c lib\mtask.h
	$(CC) dump_mem.c $(COPT)

dump_mem.exp: dump_mem.obj lib\mt_seg.obj
	$(LINK) dump_mem.obj lib\mt_seg.obj
