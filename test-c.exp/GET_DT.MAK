#

CC   = 00_cc.bat
COPT = -off Floating_point
LINK = 00_link.bat

all: get_dt.exp

get_dt.obj: get_dt.c lib\mtask.h
	$(CC) get_dt.c $(COPT)

get_dt.exp: get_dt.obj lib\mt_seg.obj
	$(LINK) get_dt.obj lib\mt_seg.obj
