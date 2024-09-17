# Free386 (386|DOS-Extender - RUN386 compatible)

This is **MS-DOS** application.
This software is compatible with 386|DOS-Extender (Phar Lap RUN386.EXE)
 and is written only in assembly language.

## Overview

* Version: 0.91
* Date: **2024-09-17**
* Author: [nabe@abk](https://twitter.com/nabe_abk)
* Target: PC/AT
* Target in Japanese: FM TOWNS, PC-9801/PC-9821
* Require: MS-DOS and XMS (with HIMEM.SYS) or TownsOS
* Available: VCPI (with EMM386.EXE)
* Language: NASM (Full assembly language)
* Licence: PDS
	* Only Free386.com and Free386's source files. This repository contains files with different licenses.

[CHANGES.txt](CHANGES.txt) for update information.

## Download

[https://github.com/nabe-abk/free386/releases](https://github.com/nabe-abk/free386/releases)

## User's Manual

* [MANUAL.md](MANUAL.md)

## Document (Japanese)

* [doc-ja/ext_api.txt](doc-ja/ext_api.txt)   - Free386 function reference
* [doc-ja/PC98.txt](doc-ja/PC98.txt)         - PC-98x1 Version's information
* [doc-ja/FM-TOWNS.txt](doc-ja/FM-TOWNS.txt) - FM TOWNS Version's information

Other Japanese documents in [doc-ja/](doc-ja/).

## PDS files

- README.md
- [MANUAL.md](MANUAL.md)
- [CHANGES.txt](CHANGES.txt)
- [bin/*](bin/)
- [src/*](src/)
- [test.com/*](test.com/)
- [test-asm.exp/*](test-asm.exp/)
- [test-c.exp/*](test-c.exp/)
- [doc-ja/dosext/*](doc-ja/dosext/)
- [f386api/*](f386api/) - Free386 original API test build.

**Other files will have different licenses.**

## Tool Files (redistributed)

* tools/nasm.exp     - NASM version 2.16.01
* tools/flatlink.exp - [FlatLink](https://github.com/nabe-abk/flatlink) - Newly developed free linker
* tools/flatlink     - FlatLink's Linux ELF binary
* tools/imake.exe    - "make" for MS-DOS (KI-Make 1.68)

## Command Line Options

```
X:\>free386.com
```

Please refer to the displayed command line help or [User's Manual](MANUAL.md).

## How to Build (on DOS)

1. Copy all files to your disk.
2. Run "make.bat". (Auto detect target machine)

## How to Build (on Linux)

1. "git clone" or copy all files to your disk.
2. Install "nasm" and "make" package. ("apt install make nasm" on Debian/Ubuntu)
3. Edit [f386def.inc](src/f386def.inc) to select the build target.
4. Run "make.sh".

## Japanese Memo

[メモという名の戯言は移動しました。](doc-ja/memo.md)

