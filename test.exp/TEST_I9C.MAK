
ASM  = free386 nasm
ASMOP=-f pharlap
LINK = free386 386linkp
#LINK = hc386

all : test_i9c.exp

test_i9c.obj: test_i9c.asm
	$(ASM) $(ASMOP) test_i9c.asm

test_i9c.exp: test_i9c.obj
 $(LINK) test_i9c -stack 1000h
