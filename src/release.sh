#!/bin/sh

mv f386def.inc f386def.org

# for TOWNS

echo "%define AUTO_RELEASE" > f386def.inc
echo "TOWNS equ 1" >>f386def.inc
echo "PC_98 equ 0" >>f386def.inc
echo "PC_AT equ 0" >>f386def.inc
cat f386def.org >>f386def.inc
make -f makefile.linux clean
make -f makefile.linux 
cp free386.com ../bin/TOWNS

# for PC-98

echo ""
echo "%define AUTO_RELEASE" > f386def.inc
echo "TOWNS equ 0" >>f386def.inc
echo "PC_98 equ 1" >>f386def.inc
echo "PC_AT equ 0" >>f386def.inc
cat f386def.org >>f386def.inc
make -f makefile.linux clean
make -f makefile.linux 
cp free386.com ../bin/PC-98

# for PC/AT

echo ""
echo "%define AUTO_RELEASE" > f386def.inc
echo "TOWNS equ 0" >>f386def.inc
echo "PC_98 equ 0" >>f386def.inc
echo "PC_AT equ 1" >>f386def.inc
cat f386def.org >>f386def.inc
make -f makefile.linux clean
make -f makefile.linux 
cp free386.com ../bin/AT

# for DOS general

echo ""
rm f386def.inc
mv f386def.org f386def.inc
make -f makefile.linux clean
make -f makefile.linux 
cp free386.com ../bin

make -f makefile.linux clean
