@echo off

echo ************************************************************
echo Auto detect build target from the execution environment.
echo Running "make.bat default" will select default build target.
echo This default is defined in "src\f386def.inc".
echo ************************************************************

cd src
..\test.com\check_pc.com %1

if ERRORLEVEL 4 goto DOS
if ERRORLEVEL 3 goto AT
if ERRORLEVEL 2 goto PC98
if ERRORLEVEL 1 goto TOWNS

..\tools\imake %1 %2 %3 %4 %5 %6 %7 %8 %9
goto exit

:TOWNS
..\tools\imake -DBUILD_TARGET=TOWNS %1 %2 %3 %4 %5 %6 %7 %8 %9
goto exit

:PC98
..\tools\imake -DBUILD_TARGET=PC98 %1 %2 %3 %4 %5 %6 %7 %8 %9
goto exit

:AT
..\tools\imake -DBUILD_TARGET=AT %1 %2 %3 %4 %5 %6 %7 %8 %9
goto exit

:DOS
..\tools\imake -DBUILD_TARGET=gen %1 %2 %3 %4 %5 %6 %7 %8 %9
goto exit


:exit
