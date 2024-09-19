
ASM   = 00_nasm.bat
ASMOP = -f obj
LINK  = 00_link.bat
LINKOP= -maxdata 1000h

all: gp_test.exp

gp_test.obj: gp_test.asm
	$(ASM) $(ASMOP) -o $@ $<

gp_test.exp: gp_test.obj
	$(LINK) $(LINKOP) -o $@ $<

