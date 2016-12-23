
ASM  = 386asm
LINK = run386 -nocrt d:\hc386\bin\386linkp
#LINK = hc386

all : test_int.exp

test_int.obj: test_int.asm
	$(ASM) test_int.asm

test_int.exp: test_int.obj
 $(LINK) test_int sub mt_int -stack 1000h
