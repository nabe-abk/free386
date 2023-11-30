#!/bin/sh

cd `dirname $0`
cd src

TARGET=free386.com

make -f makefile.lin $@

if [ -r "$TARGET" ]; then
	cp "$TARGET" ../
fi
