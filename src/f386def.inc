;******************************************************************************
; Free386 define
;******************************************************************************
;[TAB=8]
;
;==============================================================================
; Version setting
;==============================================================================
%define	VER_STRING	'Ver0.60 2016/12/24'
Major_ver	equ		00h
Minor_ver	equ		60h
F386_Date	equ		20161224h	;Develop date

;==============================================================================
; Operation setting
;==============================================================================
MEMORY_INFO	equ	0	;Internal 64KB memory information with -v opt.
INT_HOOK	equ	0	;interrupt hook and register dump
INT_REGDUMP	equ	0ffh	;interrupt for user program register dump 
PRINT_TO_FILE	equ	0	;int 21/ah=09h, Force output to "dump.txt" file

	; Target Machine / If all of zero, for DOS general purpose binary.
TOWNS		equ	1	;for FM-TOWNS binary
PC_98		equ	0	;for PC-98x1 binary
PC_AT		equ	0	;for PC/AT binary

USE_MZ_EXP	equ	1	;MP ヘッダロードルーチンを搭載する
Check_EMS	equ	1	;EMS が install されているか確認する
USE_frag_mem	equ	1	;Program末端とpage-dir間の空きメモリを使用する
USE_XMS20	equ	0	;XMS Ver2.0にも対応する（通常不要）

_TITLE_disp	equ	1	;タイトル表示
_Verbose	equ	0	;冗長な表示
_see_PATH386	equ	1	;環境変数 PATH386 を参照する
_see_PATH	equ	0	;環境変数 PATH を参照する

_reset_CRTC	equ	3	;[TOWNS] 終了時 CRTC/VRAM の初期化設定
				;	0 = 初期化せず,     1 = 初期化, 
				;	2 = CRTCのみ初期化, 3 = 自動判別
_check_MACHINE	equ	1	;簡易機種判別を行う

SAVE_8259A	equ	1	;ハードウェア割り込みマスクを終了時に復元する
Rec_Real_Vec	equ	1	;リアルモード割り込みベクタの復元

;==============================================================================
; General define
;==============================================================================
EXP_EXT		equ	'.exp'	;補完する拡張子

F386ERR		equ	0fch	;Free386内部エラー終了時のエラーコード
CPU_Fault	equ	0fdh	;CPU fault

Memory_page_max	equ	40000h	;1GB max

V86_stack_size	equ	 200h	;=byte / V86 モードスタックサイズ 
PM_stack_size	equ	 400h	;=byte / プロテクトモードスタックサイズ
VCPI_stack_size	equ	  80h	;VCPI call(to V86)時のみ使用するスタックサイズ

ISTK_size	equ	1000h	;モード切り換え時スタックサイズ（ネスト対応）
INT_BUF_size	equ	1000h	;V86←→Protect間データ渡し配列サイズ（ネスト対応）
INT_BUF_sizebits equ	12	;↑のビット数
ISTK_nest_max	equ	3	;CPUモード切り替えネスト数

work_size	equ	200h	;汎用ワークサイズ / min 200h

_POOL_mem_pages	equ	8	;ページングのために予約するメモリページ数
_CALL_buf_size	equ	4	;CALLバッファとして使用するDOSメモリサイズ (KB)
_REAL_mem_pages	equ	4	;プログラム実行用リアルメモリ (page)

Unit_of_MEM	equ	400000h	;メモリアドレスの割り当て単位(byte)
MIN_heap_mem	equ	200000h	;最小ヒープリニアアドレス

int_21h_MAXF	equ	80h	;int 21h のファンクション番号の最大値 +1
DOS_Ext_MAXF	equ	18h	;DOS-Extender拡張ファンクションの最大func番号+1

V86_flags	equ	0000h	;V86 モード時のフラグ初期値

F386_INT	equ	9ch	;Free386 独自INT番号
F386_MAX_func	equ	20h	;Free386 独自INTの最大func番号+1


;==============================================================================
;★セレクタ関係の定数
;==============================================================================
NULL_sel	equ	00h	;ヌルセレクタ
VCPI_sel	equ	68h	;VCPI 用セレクタ値は 68h ～78h

GDTsize		equ	200h	;GDT番号 0～1f8h まで
LDTsize		equ	200h	;LDT番号 4～1fch まで
IDTsize		equ	800h	;IDTの大きさ int 0-0ffh (固定)
TSSsize		equ	80h	;ディフォルトのTSS (68h Byte 以上)

LDT_sel		equ	28h	;LDTセレクタ値
LDT_RW		equ	30h	;LDTアクセス用セレクタ
GDT_RW		equ	38h	;GDTアクセス用セレクタ
IDT_RW		equ	50h	;IDTアクセス用セレクタ
TSS_sel		equ	80h	;TSSセレクタ
TSS_RW		equ	88h	;TSSアクセス用セレクタ

ALLMEM_sel	equ	40h	;全実装メモリを示すセレクタ
DOSMEM_sel	equ	60h	;DOS メモリ空間を示すセレクタ
DOSMEMsize	equ	110000h	;1MB + 64KB (HMA)

F386_cs		equ	08h	;free386用 CSセレクタ
F386_ds		equ	10h	;free386用 DSセレクタ
F386_cs2	equ	18h	;free386用 CSセレクタ / 286互換
F386_ds2	equ	20h	;free386用 DSセレクタ / 286互換

PSP_sel1	equ	24h	;PSP領域
PSP_sel2	equ	04h	;
DOSENV_sel	equ	2ch	;DOS 環境変数領域
DOSMEM_Lsel	equ	34h	;DOS メモリ空間 (in LDT)

;==============================================================================
;★固定定数
;==============================================================================

Real_Vectors	equ	100h	;リアルモードの割り込みベクタ数

;------------------------------------------------------------------------------
;TSS offset
;------------------------------------------------------------------------------

TSS_SS0_off	equ	08h	;特権レべル0 スタック初期値
TSS_ESP0_off	equ	04h	;

;==============================================================================
;★機種別の定数
;==============================================================================
;------------------------------------------------------------------------------
;for FM-TOWNS
;------------------------------------------------------------------------------
%if TOWNS

MACHINE_CODE	equ	20h	;TOWNSシリーズ
%define	MACHINE_STRING	'FM-TOWNS'

%define	Free386_API	'f386_fmt.api'	;機種固有APIのファイル名

%define	SET_TOWNS_MEM		;TOWNS 固有のメモリセレクタを配置する
INIT_KEY_BIOS	equ	1	;終了時に key-BIOS を初期化する

TBIOS_cs	equ	110h	;T-BIOS の code セレクタ
TBIOS_ds	equ	118h	;T-BIOS の data セレクタ

NSDD_max	equ	20	;NSD Driverの最大対応数（64まで設定可能）
NSDD_stra_adr	equ	06h	;strategy エントリーのあるオフセット
NSDD_intr_adr	equ	08h	;interruptエントリーのあるオフセット
NSDD_sleep	equ	0c0h	; intr/sleep  request
NSDD_wakeup	equ	0c1h	; intr/wakeup request

enable_INTR	equ	1	;プロテクトモードでの割り込みを許可する
INTR_MASTER	equ	40h	;マスタ：ハードウェア割り込み先頭
INTR_SLAVE	equ	48h	;スレーブ
I8259A_ISR_M	equ	00h	;サービスレジスタ
I8259A_ISR_S	equ	10h	;
I8259A_IMR_M	equ	02h	;マスクレジスタ
I8259A_IMR_S	equ	12h	;

%endif

;------------------------------------------------------------------------------
;for PC-9821/9801
;------------------------------------------------------------------------------
%if PC_98

MACHINE_CODE	equ	10h	;PC-98x1 シリーズ
%define	MACHINE_STRING	'PC-9801/9821'

%define	Free386_API	'f386_98.api'	;機種固有APIのファイル名

VRAM_16padr	equ 0E00A8000h	;16色VRAM を配置する物理アドレス
VRAM_CGW	equ 0E00A4000h	;CGW を配置するリニアアドレス
VRAM_TEXT	equ 0E00A0000h	;CGW を配置するリニアアドレス
STOP_GVRAM	equ	0	;終了処理でグラフィック画面の表示をoffする

enable_INTR	equ	1	;プロテクトモードでの割り込みを許可する
INTR_MASTER	equ	08h	;マスタ：ハードウェア割り込み先頭
INTR_SLAVE	equ	10h	;スレーブ
I8259A_ISR_M	equ	00h	;サービスレジスタ
I8259A_ISR_S	equ	08h	;
I8259A_IMR_M	equ	02h	;マスクレジスタ
I8259A_IMR_S	equ	0ah	;

%endif

;------------------------------------------------------------------------------
;for PC/AT
;------------------------------------------------------------------------------
%if PC_AT

MACHINE_CODE	equ	30h	;PC/AT互換機
%define	MACHINE_STRING	'PC/AT'

%define	Free386_API	'f386_at.api'	;機種固有APIのファイル名

VESA_buf_sel	equ	148h	;VESA-BIOS 用バッファのセレクタ
VESA_buf_size	equ	1	;VESA-BIOS 用バッファのサイズ(page / 1=4kb)
VESA_call_adr	equ	0ffc0h	;VESA-BIOS call を置く VESA_cs 内アドレス
				;↑call code が入りきらない誤動作する

VESA_cs		equ	150h	;VESA-BIOS の code セレクタ
VESA_ds		equ	158h	;VESA-BIOS の data セレクタ(cs alias)
VESA_ds2	equ	160h	;VESA-BIOS データ (needs 600h)
VESA_A0		equ	168h	;VESA-BIOS 用セレクタ A0000h (64kb)
VESA_B0		equ	170h	;VESA-BIOS 用セレクタ B0000h (64kb)
VESA_B8		equ	178h	;VESA-BIOS 用セレクタ B8000h (32kb)

VRAM_padr	equ 0e6000000h	;VRAM を配置する物理アドレス
VRAM_size	equ	200h	;size=8MB / [page単位] 100h=4MB
VRAM_sel	equ	120h	;VRAM セレクタ (変更時はソース即値も変更のこと)

enable_INTR	equ	1	;プロテクトモードでの割り込みを許可する
INTR_MASTER	equ	 08h	;マスタ：ハードウェア割り込み先頭
INTR_SLAVE	equ	 70h	;スレーブ
I8259A_ISR_M	equ	 20h	;サービスレジスタ
I8259A_ISR_S	equ	0a0h	;
I8259A_IMR_M	equ	 21h	;マスクレジスタ
I8259A_IMR_S	equ	0a1h	;

%endif

;------------------------------------------------------------------------------
;setting check
;------------------------------------------------------------------------------

%if (TOWNS + PC_98 + PC_AT) >1
%error You must select from "for_TOWNS, for_PC98, fot_AT", or no select.

;------------------------------------------------------------------------------
;for General DOS machine
;------------------------------------------------------------------------------

%elif (TOWNS + PC_98 + PC_AT) = 0

MACHINE_CODE	equ	00h	;無判別
%define	MACHINE_STRING	'MS-DOS'

%define	Free386_API	'f386_all.api'	;ダミー値

enable_INTR	equ	0	;プロテクトモードでの割り込み使用しない
INTR_MASTER	equ	0f0h	;ダミー値
INTR_SLAVE	equ	0f0h	;ダミー値

%endif

