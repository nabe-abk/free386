@echo off
rem 
rem Choice linker
rem 

..\tools\free386 -q ..\tools\flatlink.exp -strip %1 %2 %3 %4 %5 %6 %7 %8 %9

rem hc386 -stack 1000h %1 %2 %3 %4 %5 %6 %7 %8
rem free386 -n d:\fb386\bascom\tlinkp -stack 1000h %1 %2 %3 %4 %5 %6 %7 %8
rem free386 -n d:\hc386\bin\386linkp  -stack 1000h %1 %2 %3 %4 %5 %6 %7 %8
