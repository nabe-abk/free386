
ASM  = 386asm
LINK = free386 d:\hc386\bin\386linkp

all : mem_dump.exp

mem_dump.obj: mem_dump.asm
	$(ASM) mem_dump.asm

mem_dump.exp: mem_dump.obj
 $(LINK) mem_dump -stack 1000h
