
ASM   = 00_nasm.bat
ASMOP = -f obj
LINK  = 00_link.bat
LINKOP=

all: file_dta.exp

file_dta.obj: file_dta.asm
	$(ASM) $(ASMOP) -o $@ $<

file_dta.exp: file_dta.obj
	$(LINK) $(LINKOP) -o $@ $<

