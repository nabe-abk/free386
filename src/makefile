#----------------------------------------------------------------------------
# Free386 MAKEFILE for MS-DOS
#----------------------------------------------------------------------------

TARGET = ..\free386.com

#////////////////////////////////////////////////////////////////////
# PATH for NASM
#////////////////////////////////////////////////////////////////////
ASM    = ..\bin\free386 -q ..\tools\nasm
ASMOP  = -f obj

#ifdef BUILD_TARGET
ASMOP += -DBUILD_TARGET=$(BUILD_TARGET)
#endif

#////////////////////////////////////////////////////////////////////
# for flatlink.exp
#////////////////////////////////////////////////////////////////////
LINK   = ..\bin\free386 -q ..\tools\flatlink.exp
LINKOP =

#////////////////////////////////////////////////////////////////////
# for alink.exp
#////////////////////////////////////////////////////////////////////
# LINK   = ..\bin\free386 -q ..\tools\alink-p1.exp
# LINKOP = -oCOM -m

#====================================================================
# If you want to use Microsoft LINK.EXE, run the following.
#	..\tools\imake clean
#	..\tools\imake -f mslink.mak
#====================================================================

#------------------------------------------------------------------------------
RM = del

default: all
all: $(TARGET)

clean:
	$(RM) *.OBJ
	$(RM) OBJS
#	$(RM) $(TARGET)
#	$(RM) ..\free386.map

#------------------------------------------------------------------------------
base = macro.inc f386def.inc


start.obj: start.asm $(base)
	$(ASM) $(ASMOP) start.asm

sub.obj: sub.asm $(base)
	$(ASM) $(ASMOP) sub.asm

memory.obj: memory.asm $(base) start.inc free386.inc
	$(ASM) $(ASMOP) memory.asm

selector.obj: selector.asm $(base) free386.inc memory.inc
	$(ASM) $(ASMOP) selector.asm

sub32.obj: sub32.asm $(base) start.inc sub.inc free386.inc memory.inc selector.inc
	$(ASM) $(ASMOP) sub32.asm

call_v86.obj: call_v86.asm $(base) free386.inc memory.inc
	$(ASM) $(ASMOP) call_v86.asm

int.obj: int.asm int_dos.asm int_dosx.asm int_f386.asm int_data.asm $(base) start.inc free386.inc sub32.inc selector.inc call_v86.inc
	$(ASM) $(ASMOP) int.asm

pc.obj: pc.asm pc_towns.asm pc_98.asm pc_at.asm pc_dos.asm $(base) start.inc memory.inc selector.inc call_v86.inc free386.inc
	$(ASM) $(ASMOP) pc.asm

free386.obj: free386.asm f386def.inc f386data.asm f386prot.asm $(base) start.inc sub.inc sub32.inc memory.inc selector.inc call_v86.inc int.inc pc.inc
	$(ASM) $(ASMOP) free386.asm

$(TARGET): start.obj sub.obj memory.obj selector.obj sub32.obj call_v86.obj int.obj pc.obj free386.obj
	echo $< >OBJS
	$(LINK) $(LINKOP) -o $@ @OBJS
	$(RM) OBJS

### CAUTION!) free386.obj needs to be linked at the last. #####################

