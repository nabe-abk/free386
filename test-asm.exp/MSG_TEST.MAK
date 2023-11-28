
ASM   = 00nasm.bat
ASMOP = -f pharlap
LINK  = 00linker.bat

all: msg_test.exp

msg_test.obj: msg_test.asm
	$(ASM) $(ASMOP) msg_test.asm

msg_test.exp: msg_test.obj
	$(LINK) msg_test.obj
