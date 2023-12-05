#!/bin/sh

echo '******************************************************************'
echo 'Please edit "src/f386def.inc" for change the build target machine.'
echo '******************************************************************'

cd `dirname $0`
cd src

TARGET=free386.com

make -f makefile.lin $@

if [ -r "$TARGET" ]; then
	cp "$TARGET" ../
fi

if [ "$1" = "clean" ]; then
	cd ..
	rm -f "$TARGET"
fi
