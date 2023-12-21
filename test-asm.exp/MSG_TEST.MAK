
ASM   = 00_nasm.bat
ASMOP = -f obj
LINK  = 00_link.bat
LINKOP= -offset 4000h -maxdata 10000h

all: msg_test.exp

msg_test.obj: msg_test.asm
	$(ASM) $(ASMOP) -o $@ $<

msg_test.exp: msg_test.obj
	$(LINK) $(LINKOP) -o $@ $<
