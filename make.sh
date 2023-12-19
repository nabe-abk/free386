#!/bin/sh

echo '******************************************************************'
echo 'Please edit "src/f386def.inc" for change the build target machine.'
echo '******************************************************************'

cd `dirname $0`
cd src

make -f makefile.lin $@
