# Free386 (386|DOS-Extender - RUN386 compatible)

This is **MS-DOS** application.
This software is compatible to 386|DOS-Extender (Phar Lap RUN386.EXE).
This is written in assembly language only.

## Overview

* Version: 0.64
* Date: **2021/08/07**
* Author: [nabe@abk](https:/twitter.com/nabe_abk)
* Machine: PC/AT
* Machine in Japanese: FM-TOWNS, PC-9801/PC-9821
* Compatible: MS-DOS and XMS and **VCPI** (with HIMEM.SYS and EMM386.EXE)
* Language: NASM (Full assembly language)
* Licence: PDS (only Free386.com and Free386's source files)

[CHANGES.txt](CHANGES.txt) for update information (Japanese).

## Download

[https://github.com/nabe-abk/free386](https://github.com/nabe-abk/free386)

## Document (Japanese)

* [doc-ja/README.txt](doc-ja/README.txt) - Free386 User's Manual
* [doc-ja/api.txt](doc-ja/api.txt)       - Free386 API Reference
* [doc-ja/AT.txt](doc-ja/AT.txt)         - PC-AT    Version's information
* [doc-ja/PC98.txt](doc-ja/PC98.txt)     - PC-98x1  Version's information
* [doc-ja/FM-TOWNS.txt](doc-ja/FM-TOWNS.txt) - FM-TOWNS Version's information

## Tool Files (redistributed)

* tools/nasm.exp     - nasm-0.98.35.t03 (executable by free386.com)
* tools/alink-p1.exp - ALINK-p1 Ver1.6 patch1 (executable by free386.com)
* tools/alink-p1     - ALINK-p1 Ver1.6 patch1 (Linux ELF binary)
* tools/exe2com.exe  - compatible to exe2bin
* tools/imake        - "make" for MS-DOS

## How To Command Line

```
X:\>free386.com
```

Please refer to the displayed command line help.

## Memo by Japanese in 2016/12/21

ふとしたこから、以前製作したDOS-Extenderの「Free386」をGitHubに公開しておこうと思いました。

どうせ公開するなら、NASM や alink も一緒に収録して（DOS環境があれば）誰でもアセンブルできるようにしようと思ったのが運の尽き。alinkにフラットモード.exe/.comファイル生成時のバグを発見してしまいました。色々狂い出したのがこの辺ですね（苦笑）

alink へのパッチ作業は Linux 上で行いました。そして alink.exp を生成するために [TOWNS-gcc](http://anikun.kutami.jp/towns-gcc/) を使ったのですが、TOWNS-gcc の生成する MPヘッダ 形式の.EXPファイルが Free386 自身で実行できないバグを見つけました。これを修正しないと（普通はEXP実行環境など持っていないので）開発環境を含めての配布ができそうになありません。調べてみると、メモリの割り当て方にバグがあり、メモリ容量が8MBあたりを超え始めると、後ろの方に存在しないメモリ領域を割り当てていました。

実は、当時の Free386 はちゃんと動かないファイルが多く、動作が不安定になることもあって悩んでいたのですか、なんてことはないメモリの割り当てミスだったという。ただこれを調べるために、メモリマップやページングをダンプするツールを作成したため（収録してます）、結構な手間になりました。

さてメモリの割り当てバグが修正されると、ほぼすべてのDOS汎用EXPファイルと、多くのTOWNSソフトが動作するようになりました。しかし、TOWNS-OS最大の謎システムとされる CoCo/NSD ドライバ周りでコケてしまい、F-BASIC386で書かれたソフトなどが起動しません。**ここまで来たら動かしたくなるのが人情というもの（笑）**

そうして CoCo/NSDドライバ の解析に着手するわけです。少し調べると次のことはすぐに分かりました。

* CoCo.EXE は DOSメモリ（リアルメモリ） に常駐する。
* NSDD は 拡張メモリ に常駐する。

つまり CoCo は NSDファイル を拡張メモリにロードして、その情報を管理していると推測されます。さて問題はその管理情報をどうやって取得するかということです。[SYSINIT](http://www.purose.net/befis/download/ito/sysinit.txt)のように常駐しているCoCoメモリの中に情報があるのかな？と思いました。

とりあえず、その辺を調べるため Free386 に、割り込みをフックしてintサービスの実行前と後のレジスタ状況をダンプ出力する機能を付けました。調べる対象としては、仕組み上「NSDドライバを探す必要があり構造がより単純そうなもの」として、指定のNSDドライバを削除する機能がある \hcopy\deldrv.exp を解析しました。

```
------------------------------------------------------------------
Int = 0000_008E  CS:EIP = 000C:0000_1ADC   SS:ESP = 0014:0001_0B88
 DS = 0014        ES = 0060        FS = 0014        GS = 0014
EAX = 0000_C003  EBX = 0000_0001  ECX = 0000_0000  EDX = 0000_66EC
ESI = 0000_0246  EDI = 2074_6E00  EBP = 0001_0C48  FLG = 0000_0046
CR0 = 8000_0021  CR2 = 0000_0000  CR3 = 0002_9000    D0 S1 P1 C0  
------------------------------------------------------------------
*Ret:*
 DS = 0014        ES = 0014        FS = 0014        GS = 0014
EAX = 0000_0003  EBX = 0000_0010  ECX = 0000_0000  EDX = 0001_0C18
ESI = 0000_0246  EDI = 2074_6E00  EBP = 0001_0C48  FLG = 0000_0006
CR0 = 8000_0021  CR2 = 0000_0000  CR3 = 0002_9000    D0 S0 P1 C0  
------------------------------------------------------------------
```

こんな感じの情報が、順番にたくさん出てきます。CoCoの常駐状況などを変化させ動作の変化を見ていると、int 8eh/AX=Cx0x が、CoCoのサービスだということが分かります。同時に、int 8eh のログを取る常駐.comファイル（付属してます）を作って RUN386.EXE の挙動も調べ、両方の共通点を探ったりしながら **「自分だったら仕組みをどう設計するだろうか？」** という視点で CoCoサービス を調べていきました。

すると int 8eh/AX=C103h というドライバ常駐情報を提供するサービスまで辿り付きました。この情報を使って、拡張メモリに存在するNSDドライバを正しくメモリ上に貼り付け、セレクタ上に実装することができました。確認のために、Free386を使って deldrv.exp を実行してみたところ、NSDドライバを正しくアンインストールできました。

すばらしい。終わり。

……という風に解決したらよかったんですけどね。

TOWNS-OSというのは不思議な構造のOSでして、グラフィック処理などに32bit NativeモードのBIOS（TBIOS）があるにも関わらず、タイマなどの一部のサービスはFM-R互換の16bit動作のBIOSをそのまま使っています。16bitタイマBIOSなどに資源の管理をさせながら、32bitプログラム側からそれを使用するという意味不明な構造をしています。

酷いケースでは、タイマやキーボードなどのリアルモード資源の処理や割り込みの度に、CPUをリアルモードに切り替えて、もしそれらのリアルモードBIOS処理中に、FM音源やVSYNCなどの割り込みが発生するとBIOSの処理を中断して一旦プロテクトモードに戻ることもあるようです。

この意味不明な構造の仲介役をするのが、forRBIOS（for Real BIOS）というNSDドライバです。ちょうど、DOS-Extenderが32bitプログラムとMS-DOSの仲介役をするように、Real-mode BIOSと32bitプログラム仲介役をするわけです。

RUN386環境では forRBIOS.NSD が組み込まれていると、int 8eh などの割り込みベクタが書き換えられ、NSDドライバが割り込みを取得するようになります。**この情報は一体どこにあるのか？** ということが残された謎でした。しかし、RUN386 が .EXP を実行するまでのINTのログをいくらとってもそれらしいものがありません。常駐している CoCo のメモリを見てみてもそれらしい情報がありません。

もしや「常駐しているNSD自身に初期化させてるのでは？」と思い、常駐している forRBIOS のエントリーにパッチを充て、サービスルーチンが呼び出された時に無限ループに陥るという荒業を使ってみたところビンゴでした。

ようやく、F-BASIC386 などで生成した EXPファイル が実行できるようになりました。解析結果は doc 内に収録してあります。ちなみに、forRBIOSを必要としない（High-C等で書かれた）プログラムを実行する際に、forRBIOS を初期化すると初期化しない時に比べ全体の処理が遅くなります。本当にここは TOWNS-OS のクソ仕様だと思います。


そんなこんなで、2001年の開発停止から十数年ぶりに CoCo の謎が解決され、RUN386 と互換性の高い DOS-Extender が出来ました、ということで。
