@echo off
rem 
rem Choice linker
rem 

run386 -nocrt d:\fb386\bascom\tlinkp %1 %2 %3 %4 %5 %6 %7 %8 %9 -stack 1000h

rem run386  -nocrt d:\hc386\bin\386linkp %1 %2 %3 %4 %5 %6 %7 %8 %9 -stack 1000h
rem free386 -n     d:\hc386\bin\386linkp %1 %2 %3 %4 %5 %6 %7 %8 %9 -stack 1000h
