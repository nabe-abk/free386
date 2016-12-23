#----------------------------------------------------------------------------
#
#	use	NASM 0.98+towns02 以降
#
#----------------------------------------------------------------------------

#///////////////////////////////////////////////////////////////////
# free386 は PATH386 の、EXE386 は PATH の自動検索機能を持ってます。

#ASM  =run386 -nocrt e:\tool\nasm\nasm.exp
#ASM  =exe386 nasm.exp
ASM  =free386 nasm
ASMOP=-f pharlap


#///////////////////////////////////////////////////////////////////
#High-C 付属の linker を使用する場合
#
LINK   = 386link
LINKOP = -exe f386.api -stack 100h -maxdata 100h -nomap

#------------------------------------------------------------------------------

all : f386.api

api_spl.obj: api_spl.asm
	$(ASM) $(ASMOP) api_spl.asm

f386.api: api_spl.obj f386alib.obj
	$(LINK) api_spl f386alib $(LINKOP)
