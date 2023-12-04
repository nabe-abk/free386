@echo off
rem 
rem Choice linker
rem 

hc386 %1 %2 %3 %4 %5 %6 %7 %8 -stack 1000h

rem free386 -n d:\fb386\bascom\tlinkp %1 %2 %3 %4 %5 %6 %7 %8 -stack 1000h
rem free386 -n d:\hc386\bin\386linkp  %1 %2 %3 %4 %5 %6 %7 %8 -stack 1000h
