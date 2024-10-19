#!/bin/sh

echo '******************************************************************'
echo 'Target argument: towns / 98 / at / gen'
echo 'Please edit "src/f386def.inc" for change the default build target.'
echo '******************************************************************'

cd `dirname $0`
cd src

BUILD_TARGET=default
if [ "$1" = "towns" ]; then
	export BUILD_TARGET=towns
	shift

elif [ "$1" = "98" -o "$1" = "pc98" ]; then
	export BUILD_TARGET=98
	shift

elif [ "$1" = "at" ]; then
	export BUILD_TARGET=at
	shift

elif [ "$1" = "gen" -o "$1" = "uni" -o "$1" = "dos" ]; then
	export BUILD_TARGET=gen
	shift
fi

make -f makefile.lin $OPT $@

if [ "$1" = "clean" ]; then
	cd ..
	rm -f free386.com free386.map
else
	echo
	echo Build target is $BUILD_TARGET
fi
