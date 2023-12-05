# Free386 User's Manual

This software is a DOS-Extender that is almost compatible with Phar-Lap RUN386.
This is works with "FM TOWNS" and "PC-9801(9821)" and "AT compatible machines".

* This software can run .EXP format (P3 or MP format) files on DOS.
* This software required XMS and VCPI memory server.
	* Most require HIMEM.SYS and EMM386.EXE for MS-DOS Version 5 or later.

このソフトは、Phar-Lap RUN386 ほぼ互換の DOS-Extender です。
FM TOWNS / PC-98x1 / AT互換機で動作します。

- このソフトは .EXP 形式（P3 or MP形式）のファイルを実行することができます。
- 実行には XMS メモリサーバ、VCPI メモリサーバが必要です。
	- 多くの場合、MS-DOS Ver5 以降の HIMEM.SYS と EMM386.EXE が必要です。

## Usage

```
> free386 [-options] <target.exp>
```

* Displays help if no arguments are specified.
* The executable file extension ".exp" can be omitted.
* Automatically searches for executable files by referring to the environment variable PATH386.

- 引数を指定しない場合、ヘルプを表示します。
- 実行ファイルの拡張子 ".exp" は省略できます。
- 環境変数 PATH386 を参照し、実行ファイルを自動検索します。

## Options

* -v
	* Verbose. Mainly displays information about memory.
* -vv
	* More verbose.
* -q
	* Do not output Free386's title and help.
* -p0 (default)
* -p1
	* -p1 After the environment variable PATH386, the environment variable PATH to find the EXP executable file.
* -m
	* Memory pages reserved for paging are set to '1'.
	* Real memory reserved for DOS is set to 0 bytes and 
	  allocate as much memory as possible for "EXP" file.
	* Note) It is not completely 0 bytes due to 4KB fragmentation.
* -2
	* Set PharLap's DOS-Extender Version information to "2.2". Usually "1.2".
* -c0
* -c1, -c
* -c2
* -c3 (default)
	* Set automatic reset of CRTC and VRAM. This function is only implemented in FM TOWNS and PC-98.
	* -c0 Not initialize.
	* -c1 Always initialize.
	* -c2 Initialize only the screen mode.
	* -c3 Automatically detect and initialize if necessary.
* -i0, -i
* -i1 (default)
	* -i1 Auto detect machines type for prevents execution of Free386 binaries on different machines.
* -n (only TOWNS)
	* Do not initialize CoCo/NSD driver. Improved execution speed for EXP files that do not require CoCo.

## Options (in Japanese)

* -v
	* メモリに関する情報を表示します。
* -vv
	* より冗長な表示を行います。
* -q
	* Free386のタイトルとヘルプを表示しない。
* -p0 (default)
* -p1
	* -p1 環境変数PATH386の次に、環境変数PATHを参照して EXP実行ファイルを検索します。
* -m
	* ページテーブル用予備メモリページ数を1に設定します。
    * DOS用に空けておくメモリを0バイトに設定し、可能な限り多くのメモリをEXP用に割り当てます。
    * ※メモリは4KBごとでしか使用できないため、空きDOSメモリは完全に0byteにはなりません。
* -2
	* PharLapのDOS-Extender Version情報を "2.2" に設定します。通常は "1.2" です。
* -c0
* -c1
* -c2
* -c3 (default)
	* CRTCやVRAMの自動リセットを設定します。この機能は FM TOWNS 及び PC-98 のみ実装されています。
	* -c0 初期化しない。
	* -c1 常に初期化する。
	* -c2 画面モードのみ初期化する。
	* -c3 初期化するかは自動判別する。
* -i, -i0
* -i1 (default)
	* -i1 実行時機種判別を行い、機種の異なるFree386バイナリの実行を防止します。
* -n (only TOWNS)
	* CoCo/NSD ドライバの初期化を行わず、CoCoが不要なEXPファイルにおいて動作速度を向上させます。

## Binary Hack for default setting

free386.com has behavior definition variables at the beginning of the file,
and you can change the default behavior by rewriting them.
Please use your favorite binary editor for rewriting.

free386.com はファイル先頭に動作定義変数を持っており、書き換えることでデフォルトの動作を変更できます。
書き換えにはお好みのバイナリエディタを使用してください。

|offset	|default|size| detail |
|------	| ----- |----| ------ |
| +04h	|  1	|  b | Show Free386's title: 0=off, 1=on |
| +05h	|  0	|  b | Performs verbose: 0=off, 1=on, 2=more verbose (See -v option) |
| +06h	|  1	|  b | Find target exp file from PATH386 of enviroment variable: 0=off, 1=on |
| +07h	|  0	|  b | Find target exp file from PATH of enviroment variable: 0=off, 1=on (See -p option) |
| +08h	|  3	|  b | Auto CRTC/VRAM clear. (See -c option) |
| +09h	|  1	|  b | Auto detect machines type: 0=off, 1=on (See -i option) |
| +0ah	|  0	|  b | (Reserved) |
| +0bh	|  0	|  b | (Reserved) |
| +0ch	|  8	|  b | Reserved memory pages for paging table (unit is page). 1page=4KB. |
| +0dh	| 16	|  b | Call buffer size (KB). Use 16bit<->32bit function call. min 4KB. |
| +0eh	| 32	|  w | Reserved minimum DOS memory(KB). |

In addition, if you want to rewrite the default value of PharLap's DOS-Extender Version information,
search for the string "12aJ" (31 32 61 4A) and rewrite it to "22d " (32 32 64 20) or other.

| 位置	| 標準	|size| 詳細l |
|------	| ----- |----| ------ |
| +04h	|  1	|  b | 実行時にFree386のタイトルを表示します: 0=off, 1=on |
| +05h	|  0	|  b | 実行時にメモリ情報等を表示します: 0=off, 1=on, 2=多く表示 |
| +06h	|  1	|  b | 環境変数PATH386の中から実行対象のEXPファイルを検索します: 0=off, 1=on |
| +07h	|  0	|  b | 環境変数PATHの中から実行対象のEXPファイルを検索します: 0=off, 1=on |
| +08h	|  3	|  b | 自動 CRTC/VRAM 初期化の初期値を設定します（"-c"オプション参照） |
| +09h	|  1	|  b | 機種判別機能を実行します: 0=off, 1=on （"-i"オプション参照）|
| +0ah	|  0	|  b | （予約済） |
| +0bh	|  0	|  b | （予約済） |
| +0ch	|  8	|  b | ページングテーブル用の予約済ページ数（単位ページ数）。1ページ=4KB。 |
| +0dh	| 16	|  b | コールバッファサイズKB単位で設定します。最小は4KBです。 |
| +0eh	| 32	|  w | 空けておくDOSメモリの量をKB単位で設定します。 |

その他、PharLapのDOS-Extender Version情報のデフォルト値を書き換えたいときは、
"12aJ"(31 32 61 4A)の文字列検索し、"22d "(32 32 64 20)等に書き換えてください。

## Known issues

* Usable memory is limited to a maximum of 1GB.
* In the DOS function "Write string to STDOUT"(int 21h, AH=09),
  if the data size exceeds the "call buffer size", the excess data will be truncated.
* When issuing a DOS function, the carry flag may change even though it should originally be saved.

- 使用できる最大メモリが1GBに制限されています。
- DOS function の文字列出力（int 21h, AH=09h）において、
  データサイズがコールバッファサイズを越えた場合、越えた分のデータが切捨てられます。
- DOS function 発行時、本来キャリーフラグが保存されるべきものにおいて、
  キャリーフラグが変化してしまうことがあります。

