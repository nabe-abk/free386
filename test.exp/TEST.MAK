
ASM  = 386asm
LINK = run386 -nocrt d:\hc386\bin\386linkp
#LINK = hc386

all : test.exp

test.obj: test.asm
	$(ASM) test.asm

test.exp: test.obj
 $(LINK) test sub -stack 1000h
