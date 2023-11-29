
ASM   = .\00nasm.bat
ASMOP = -f pharlap
LINK  = .\00linker.bat
LINKOP= -offset 4000h -maxdata 10000h

all: msg_test.exp

msg_test.obj: msg_test.asm
	$(ASM) $(ASMOP) msg_test.asm

msg_test.exp: msg_test.obj
	$(LINK) $(LINKOP) msg_test.obj
