#!/bin/sh

echo '******************************************************************'
echo 'Please edit "src/f386def.inc" for change the build target machine.'
echo '******************************************************************'

cd `dirname $0`
cd src

make -f makefile.lin $@

if [ "$1" = "clean" ]; then
	cd ..
	rm -f free386.com free386.map
fi
