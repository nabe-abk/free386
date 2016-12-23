#----------------------------------------------------------------------------
#Free386 MAKEFILE
#
#	use	NASM 0.98+towns02 or +towns03 only
#	linker	MS-Link
#	com	exe2bin
#
#----------------------------------------------------------------------------

#
#※本家 NASM 0.98 等では %include 命令のバグによりアセンブル中にハングします。
#　free386.asm の %include 命令を減らしてください -> free386.asm に統合する
#

#///////////////////////////////////////////////////////////////////
# free386 は PATH386 の、EXE386 は PATH の自動検索機能を持ってます。

#ASM  =run386 -nocrt e:\tool\nasm\nasm.exp
#ASM  =exe386 nasm.exp
ASM  =free386 nasm
ASMOP=-f obj


#///////////////////////////////////////////////////////////////////
#MS linker を使用する場合
#
LINK    = link
MSLINKOP= ,free386.exe,nul,,nul

#///////////////////////////////////////////////////////////////////
#Turbo linker を使用する場合
#
#LINK    = link
#LINKOP  = /3
#MSLINKOP= ,free386.exe,nul,,nul

#///////////////////////////////////////////////////////////////////
#High-C 付属の linker を使用する場合
#
#LINK   = free386 386linkp
#LINKOP = -86 -exe free386.exe

#///////////////////////////////////////////////////////////////////
#F-BASIC386付属の linker を使用する場合
#  (このリンカは High-C付属linker とバージョン違い + 改造品に思える)
#
#LINK   = free386 d:\fb386\bascom\tlinkp
#LINKOP = -86 -exe free386.exe

#///////////////////////////////////////////////////////////////////
#alink.exp を使用する場合
#
#LINK   = free386 alink
#LINKOP = -oEXE -o free386.exe



#///////////////////////////////////////////////////////////////////
#com ファイル変換
#
COM  =exe2bin
#COM  =exe2com
#COM  =free386 exe2com

#------------------------------------------------------------------------------

all : free386.com

start.obj: start.asm f386def.inc
	$(ASM) $(ASMOP) start.asm

sub.obj: sub.asm f386def.inc
	$(ASM) $(ASMOP) sub.asm

f386sub.obj: f386sub.asm f386def.inc f386seg.inc start.inc
	$(ASM) $(ASMOP) f386sub.asm

f386seg.obj: f386seg.asm f386def.inc free386.inc
	$(ASM) $(ASMOP) f386seg.asm

f386cv86.obj: f386cv86.asm f386def.inc free386.inc macro.asm
	$(ASM) $(ASMOP) f386cv86.asm

int.obj: int.asm int_dos.asm int_dosx.asm int_f386.asm int_data.asm macro.asm f386def.inc
	$(ASM) $(ASMOP) int.asm

free386.obj: free386.asm f386def.inc f386data.asm f386prot.asm towns.asm at.asm pc98.asm
	$(ASM) $(ASMOP) free386.asm

free386.exe: start.obj f386sub.obj free386.obj sub.obj f386seg.obj f386cv86.obj int.obj
	$(LINK) $(LINKOP) start.obj sub.obj f386sub.obj f386seg.obj f386cv86.obj int.obj free386.obj$(MSLINKOP)
#------注意：free386.obj を必ず最後尾にリンクすること！！------

free386.com: free386.exe
	$(COM) free386.exe free386.com
