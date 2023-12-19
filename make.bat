@echo off

echo ******************************************************************
echo Please edit "src\f386def.inc" for change the build target machine.
echo ******************************************************************

cd src
..\tools\imake %1 %2 %3 %4 %5 %6 %7 %8 %9

