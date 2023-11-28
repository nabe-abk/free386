# Free386 (386|DOS-Extender - RUN386 compatible)

This is **MS-DOS** application.
This software is compatible to 386|DOS-Extender (Phar Lap RUN386.EXE).
This is written in assembly language only.

## Overview

* Version: 0.66
* Date: **2023/11/28**
* Author: [nabe@abk](https:/twitter.com/nabe_abk)
* Machine: PC/AT
* Machine in Japanese: FM-TOWNS, PC-9801/PC-9821
* Compatible: MS-DOS and XMS and **VCPI** (with HIMEM.SYS and EMM386.EXE)
* Language: NASM (Full assembly language)
* Licence: PDS (only Free386.com and Free386's source files)

[CHANGES.txt](CHANGES.txt) for update information.

## Download

[https://github.com/nabe-abk/free386](https://github.com/nabe-abk/free386)

## User's Manual

* [MANUAL.md](MANUAL.md)

## Document (Japanese)

* [doc-ja/PC98.txt](doc-ja/PC98.txt)     - PC-98x1 Version's information
* [doc-ja/FM-TOWNS.txt](doc-ja/FM-TOWNS.txt) - FM-TOWNS Version's information
* [doc-ja/ext_api.txt](doc-ja/ext_api.txt)       - DOS-Extenter functions reference

Other Japanese documents in [doc-ja/](doc-ja/).

## PDS files

- README.md
- [CHANGES.txt](CHANGES.txt)
- [bin/*](bin/)
- [src/*](src/)
- [test.com/*](test.com/)
- [test.exp/*](test.exp/)
- [doc-ja/dosext/*](doc-ja/dosext/)
- [f386api/*](f386api/) - Free386 original API test build.

**Other files will have different licenses.**

## Tool Files (redistributed)

* tools/nasm.exp     - nasm-0.98.35.t03 (executable by free386.com)
* tools/alink-p1.exp - ALINK-p1 Ver1.6 patch1 (executable by free386.com)
* tools/alink-p1     - ALINK-p1 Ver1.6 patch1 (Linux ELF binary)
* tools/exe2com.exe  - compatible to exe2bin
* tools/imake.exe    - "make" for MS-DOS

## How to Command Line

```
X:\>free386.com
```

Please refer to the displayed command line help or [User's Manual](MANUAL.md).

## How to Build (on DOS)

1. Copy all files to your disk.
2. Edit [f386def.inc](src/f386def.inc) to select the build target.
3. Run "make.bat".

## How to Build (on Linux)

1. "git clone" or copy all files to your disk.
2. Install "nasm" and "make" package. ("apt install make nasm" on Debian/Ubuntu)
3. Edit [f386def.inc] to select the build target.
4. Run "make.sh".

