#!/bin/sh

echo '******************************************************************'
echo 'Target argument: towns / 98 / at / gen'
echo 'Please edit "src/f386def.inc" for change the default build target.'
echo '******************************************************************'

cd `dirname $0`
cd src

OPT=
if [ "$1" = "towns" ]; then
	OPT="FREE386_TARGET=towns"
	shift

elif [ "$1" = "98" -o "$1" = "pc98" ]; then
	OPT="FREE386_TARGET=98"
	shift

elif [ "$1" = "at" ]; then
	OPT="FREE386_TARGET=at"
	shift

elif [ "$1" = "gen" -o "$1" = "uni" ]; then
	OPT="FREE386_TARGET=gen"
	shift
fi

make -f makefile.lin $OPT $@

if [ "$1" = "clean" ]; then
	cd ..
	rm -f free386.com free386.map
fi
