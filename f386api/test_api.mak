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
LINKOP = -exe test_api.exp -stack 1000h -maxdata 1000h

#------------------------------------------------------------------------------

all : test_api.exp

test_api.obj: test_api.asm
	$(ASM) $(ASMOP) test_api.asm

test_api.exp: test_api.obj
	$(LINK) test_api $(LINKOP)
