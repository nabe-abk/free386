#!/bin/sh

cd `dirname $0`

MAKEFILE=makefile.tmp

if [ "$1" = "clean" ]; then
	rm -f *.map *.obj *.MAP *.OBJ $MAKEFILE
	exit
fi

for f in *.MAK; do
	sed -E '
		s/ASM\s*=.*/ASM=nasm/g;
		s/LINK\s*=.*/LINK=..\/tools\/flatlink -strip/g;
		s/\w\w*\.(asm|obj|exp)/\U\0/g;
	' $f >$MAKEFILE
	make -f $MAKEFILE
	echo
done

rm -f $MAKEFILE
