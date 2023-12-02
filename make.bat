@echo off
cd src
..\tools\imake %1 %2 %3 %4 %5 %6 %7 %8 %9
copy free386.com ..
cd ..
