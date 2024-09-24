
CC   = 00_cc.bat
COPT = -off Floating_point
LINK = 00_link.bat

all: bench.exp

bench.obj: bench.c
	$(CC) bench.c $(COPT)

bench.exp: bench.obj lib\benchlib.obj
	$(LINK) bench.obj lib\benchlib.obj
