
ASM  = free386 nasm
ASMOP=-f pharlap
LINK = free386 386linkp
#LINK = hc386

all : inf_loop.exp

inf_loop.obj: inf_loop.asm
	$(ASM) $(ASMOP) inf_loop.asm

inf_loop.exp: inf_loop.obj
 $(LINK) inf_loop -stack 1000h
