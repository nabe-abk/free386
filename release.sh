#!/bin/sh

cd `dirname $0`
cd src

mv f386def.inc f386def.org

# for TOWNS

echo "%define AUTO_RELEASE" > f386def.inc
echo "TOWNS equ 1" >>f386def.inc
echo "PC_98 equ 0" >>f386def.inc
echo "PC_AT equ 0" >>f386def.inc
cat f386def.org >>f386def.inc
make -f makefile.lin clean
make -f makefile.lin 

echo free386.com ../bin/TOWNS
cp   free386.com ../bin/TOWNS

# for PC-98

echo ""
echo "%define AUTO_RELEASE" > f386def.inc
echo "TOWNS equ 0" >>f386def.inc
echo "PC_98 equ 1" >>f386def.inc
echo "PC_AT equ 0" >>f386def.inc
cat f386def.org >>f386def.inc
make -f makefile.lin clean
make -f makefile.lin 

echo free386.com ../bin/PC-98
cp   free386.com ../bin/PC-98

# for PC/AT

echo ""
echo "%define AUTO_RELEASE" > f386def.inc
echo "TOWNS equ 0" >>f386def.inc
echo "PC_98 equ 0" >>f386def.inc
echo "PC_AT equ 1" >>f386def.inc
cat f386def.org >>f386def.inc
make -f makefile.lin clean
make -f makefile.lin 

echo free386.com ../bin/AT
cp   free386.com ../bin/AT

# for DOS general

echo ""
echo "%define AUTO_RELEASE" > f386def.inc
echo "TOWNS equ 0" >>f386def.inc
echo "PC_98 equ 0" >>f386def.inc
echo "PC_AT equ 0" >>f386def.inc
cat f386def.org >>f386def.inc
make -f makefile.lin clean
make -f makefile.lin 

echo free386.com ../bin
cp   free386.com ../bin

# cleanup

echo ""
rm f386def.inc
mv f386def.org f386def.inc
make -f makefile.lin clean
