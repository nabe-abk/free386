#----------------------------------------------------------------------------
# Free386 MAKEFILE for DOS
#----------------------------------------------------------------------------

RM = del

#///////////////////////////////////////////////////////////////////
# PATH for NASM
#///////////////////////////////////////////////////////////////////
ASM    = ..\bin\free386 ..\tools\nasm
ASMOP  = -f obj

#///////////////////////////////////////////////////////////////////
# for alink.exp
#///////////////////////////////////////////////////////////////////
LINK   = ..\bin\free386 ..\tools\alink-p1.exp
LINKOP = -oCOM -o free386.com

#------------------------------------------------------------------------------
all: free386.com

clean:
	$(RM) *.obj
	$(RM) free386.com

#------------------------------------------------------------------------------

start.obj: start.asm f386def.inc
	$(ASM) $(ASMOP) start.asm

sub.obj: sub.asm f386def.inc f386sub.inc
	$(ASM) $(ASMOP) sub.asm

f386sub.obj: f386sub.asm f386def.inc f386seg.inc start.inc
	$(ASM) $(ASMOP) f386sub.asm

f386seg.obj: f386seg.asm f386def.inc free386.inc f386sub.inc
	$(ASM) $(ASMOP) f386seg.asm

f386cv86.obj: f386cv86.asm f386def.inc free386.inc macro.asm
	$(ASM) $(ASMOP) f386cv86.asm

int.obj: int.asm int_dos.asm int_dosx.asm int_f386.asm int_data.asm macro.asm start.inc f386def.inc f386sub.inc f386seg.inc f386cv86.inc free386.inc
	$(ASM) $(ASMOP) int.asm

free386.obj: free386.asm f386def.inc f386data.asm f386prot.asm towns.asm at.asm pc98.asm start.inc sub.inc f386sub.inc f386seg.inc f386cv86.inc int.inc
	$(ASM) $(ASMOP) free386.asm

free386.com: start.obj f386sub.obj free386.obj sub.obj f386seg.obj f386cv86.obj int.obj
	$(LINK) $(LINKOP) start.obj sub.obj f386sub.obj f386seg.obj f386cv86.obj int.obj free386.obj

### CAUTION!) free386.obj needs to be linked at the last. #####################


