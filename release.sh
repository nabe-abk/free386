#!/bin/sh

cd `dirname $0`

DIRS="
	bin
	bin/TOWNS
	bin/PC-98
	bin/AT
"

for d in $DIRS; do
	if [ ! -e "$d" ]; then
		mkdir $d
	fi
	rm -f "$d/free386.com"
done

#--------------------------------------------------------------------
# make
#--------------------------------------------------------------------
cd src

make -f makefile.lin clean
make -f makefile.lin BUILD_TARGET=TOWNS

echo mv ../free386.com ../bin/TOWNS
     mv ../free386.com ../bin/TOWNS
echo

# for PC-98

make -f makefile.lin clean
make -f makefile.lin BUILD_TARGET=PC_98

echo mv ../free386.com ../bin/PC-98
     mv ../free386.com ../bin/PC-98
echo

# for PC/AT

make -f makefile.lin clean
make -f makefile.lin BUILD_TARGET=AT

echo mv ../free386.com ../bin/AT
     mv ../free386.com ../bin/AT
echo

# for DOS general

make -f makefile.lin clean
make -f makefile.lin BUILD_TARGET=gen

echo mv ../free386.com ../bin
     mv ../free386.com ../bin
echo

# cleanup

make -f makefile.lin clean

cd ..
#--------------------------------------------------------------------
# check
#--------------------------------------------------------------------

echo
for d in $DIRS; do
	if [ ! -e "$d/free386.com" ]; then
		echo "$d/free386.com does not exists!"
	fi
done

