#!/bin/sh

ASMOPT="-f obj"
LNKOPT="-mindata 1000h -strip"


if [ "$1" = "clean" ]; then
	rm -f *.map *.obj *.OBJ
	exit
fi



echo "%define PC98"   >VSYNC_98.ASM
cat  VSYN_CNT.ASM    >>VSYNC_98.ASM
echo "%define TOWNS"  >VSYNC_FM.ASM
cat  VSYN_CNT.ASM    >>VSYNC_FM.ASM
mv   VSYN_CNT.ASM VSYN_CNT.AS

for f in *.ASM; do
	base=`basename "$f" .ASM`
	echo nasm $ASMOPT -o "$base.OBJ" "$f"
	     nasm $ASMOPT -o "$base.OBJ" "$f"
	echo ../tools/flatlink $LNKOPT -o "$base.EXP" "$base.OBJ"
	     ../tools/flatlink $LNKOPT -o "$base.EXP" "$base.OBJ"
	echo
done

rm -f VSYNC_98.ASM VSYNC_FM.ASM
mv VSYN_CNT.AS  VSYN_CNT.ASM

