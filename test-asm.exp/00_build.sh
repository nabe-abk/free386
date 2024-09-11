#!/bin/sh

cd `dirname $0`

MAKEFILE=makefile.tmp

if [ "$1" = "clean" ]; then
	rm -f *.map *.lst *.obj *.MAP *.LST *.OBJ $MAKEFILE
	exit
fi

if [ "$1" = "" ]; then
	FILES=*.MAK
else
	FILES=`echo -n $1 | tr '[:lower:]' '[:upper:]'`.MAK
fi

for f in $FILES; do
	sed -E '
		s/ASM\s*=.*/ASM=nasm/g;
		s/LINK\s*=.*/LINK=..\/tools\/flatlink -strip/g;
		s/\w\w*\.(asm|obj|exp)/\U\0/g;
	' $f >$MAKEFILE
	make -f $MAKEFILE
	echo
done

rm -f $MAKEFILE
