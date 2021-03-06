;******************************************************************************
;　Free386　＜データ部＞
;******************************************************************************
;
segment	data align=16 class=CODE use16
group	comgroup text data
;
;==============================================================================
;★設定
;==============================================================================
env_PATH386	db	'PATH386',0	;ファイル検索時に参照する環境変数
env_PATH	db	'PATH',0	;

default_API	db	Free386_API,0	;ディフォルトの API


;==============================================================================
	align	4
;--------------------------------------------------------------------
;----- バッファ情報 -------------------------------------------------
;
work_adr	dd	0		;汎用ワークのアドレス (min 200h)
callbuf_adr16	dw	0		; offset / for DOS-X ax=250dh
callbuf_seg16	dw	0		; segment / min 1KB
callbuf_adr32	dd	0		;リニアモードアドレス

int_buf_adr	dd	0		;int 21h等/nest対応
int_rwbuf_adr	dd	0		;File R/W専用バッファアドレス
int_rwbuf_size	dd	INT_RWBUF_size	;サイズ

int_buf_adr_org		dd	0	;バッファアドレス初期値
int_rwbuf_adr_org	dd	0	;

;--------------------------------------------------------------------
;----- 一般の内部変数 -----------------------------------------------
;
err_level	db	0		;プログラムエラーレベル
f386err		db	0		;F386 内部エラーレベル
init_machine	db	0		;initalized machin local

;--------------------------------------------------------------------
;----- メモリ関連情報 -----------------------------------------------
;
	;ページディレクトリやページテーブルは 4KB にalign されなければならず、
	;プログラム終端との間に使われないメモリ領域が発生してしまう
	align	4
frag_mem_offset	dd	offset end_adr	;プログラム末端（データ領域含む）
frag_mem_size	dd	0		;内部でセーブ
top_mem_offset	dd	0		;自由に使える一番上位のメモリ
down_mem_offset	dd	10000h & 0ffffh	;自由に使える一番下位のメモリ+1

PM_stack_adr	dd	0		;プロテクトモード時のスタック
		dw	F386_ds		;

VCPI_stack_adr	dd	0		;V86 モード切り換え時のみ
		dw	F386_ds		;　使用するスタック

v86_cs		dw	0,0		;V86モード時 cs
v86_sp		dw	0,0		;V86モード時 sp

		align	4
GDT_adr		dd	0		;GDT のオフセット
LDT_adr		dd	0		;LDT のオフセット
IDT_adr		dd	0		;IDT のオフセット
TSS_adr		dd	0		;TSS のオフセット

;--------------------------------------------------------------------
;----- XMS 関連データ領域 -------------------------------------------
;
XMS_Ver		dd	0		;XMS のメジャー Version
XMS_entry	dd	0		;XMS 呼び出しアドレス

EMB_handle	dd	0		;EMB ハンドル
EMB_physi_adr	dd	0		;EMB 先頭物理ドレス (4KB単位で値調整済)
EMB_pages	dd	0		;EMB サイズ(byte) / 4 KB (端数調整済)

EMB_top_adr	dd	0		;管理する EMB の最上位アドレス / XMS3.0
max_EMB_free	dd	0		;最大の EMB 空きメモリサイズ    (Kbyte)
total_EMB_free	dd	0		;トータルの EMB 空きメモリサイズ(Kbyte)

DOS_mem_adr	dd	0		;確保したDOSメモリのアドレス
DOS_mem_pages	dd	0		;確保したページ数

;--------------------------------------------------------------------
;----- プロテクトメモリ管理情報 -------------------------------------
;
free_LINER_ADR	dd	0		;未定義(未使用)リニアアドレス (最低位)
free_RAM_padr	dd	0		;空き先頭物理RAMページアドレス
free_RAM_pages	dd	0		;利用可能な物理RAMページ数 (4KB単位)

	;以下 VCPI からと関連の濃いもの
all_mem_pages	dd	0		;物理メモリ、総メモリページ数
vcpi_mem_pages	dd	0		;VCPI の管理するメモリページ数

page_dir	dw	0,0	;F386ds	;ページディレクトリ オフセット
page_table0	dw	0,0	;F386ds	;ページテーブル0 オフセット

;--------------------------------------------------------------------
;----- データ領域 ---------------------------------------------------
;
	align	4
top_adr		dd	0		;プログラム先頭リニアアドレス
intr_mask_org	dw	0		;8259A オリジナル値バックアップ

DTA_off		dd	80h		;DTA 初期値
DTA_seg		dw	PSP_sel1,0	;

;----- データ領域２ -------------------------------------------------
;
	align	16
LGDT_data	dw	GDTsize-1	;GDT リミット
		dd	0		;    リニアアドレス
LIDT_data	dw	IDTsize-1	;IDT リミット
		dd	0		;    リニアアドレス

DOS_int21h_adr	dd	0		;DOS int 21h   CS:IP
VCPI_entry	dd	0		;VCPI サービスエントリ
		dw	VCPI_sel	;VCPI セレクタ


	;/// リアルモードベクタ設定用データ領域 ////////
	align	4
RVects_flag_tbl	resb	Real_Vectors /8	;書き換えフラグ テーブル
RVects_save_adr	dd	0		;リアルモードベクタ保存のアドレス

;
;----- VCPI関連データ領域 -------------------------------------------
;

	align	4
to_PM_data_ladr	dd	0	;下記構造体リニアアドレス

to_PM_data:			;V86 → PM構造体
to_PM_CR3	dd	0
to_PM_GDTR	dd	0
to_PM_IDTR	dd	0
to_PM_LDTR	dw	LDT_sel
to_PM_TR	dw	TSS_sel
to_PM_EIP	dd	0
to_PM_CS	dw	F386_cs

	align	4
VCPI_cr3	dd	0		;

;
;----- メッセージ ---------------------------------------------------
;
P_title	db	'Free386(386|DOS-Extender) for '
	db	MACHINE_STRING
	db	' ',VER_STRING
	db	' (C)nabe@abk',13,10,'$'

EXE_err	db	'Do not execute free386.exe (Please run free386.com)',13,10,'$'

end_mes	db	'Finish',13,10,'$'

msg_01	db	'VCPI Found：VCPI Version $'
msg_02	db	'[VCPI] Physical Memory size = '
msg_02a	db	'###### KB',13,10
	db	'[XMS]  Allocate Ext  Memory = '
msg_02b	db	'###### KB ('
msg_02c	db	'####_####h)',13,10
	db	'[DOS]  Allocate Real Memory = '
msg_02d	db	'###### KB ('
msg_02e	db	'####_####h) + 4KB(fragment)',13,10
	db	'[DOS]  Call Buffer Memory   = '
msg_02f	db	'###### KB ('
msg_02g	db	'####_####h)',13,10
	db	'[DOS]  Free386.com Memory   = '
msg_02h	db	'    64 KB ('
msg_02i	db	'####_####h)',13,10
	db	'$'
msg_05	db	'Load file name = $'
msg_06	db	'Found XMS 2.0',13,10,'$'
msg_07	db	'Found XMS 3.0',13,10,'$'
msg_10	db	'(RUN) free386 program.exp',13,10
	db	13,10
	db	'	-v      Verbose (memory information and other)',13,10
	db	'	-p      Search .exp file from PATH (with default from PATH386)',13,10
	db	'	-m      Use memory to the maximum with real memory',13,10
%if MACHINE_CODE
	db	'	-c?     Reset CRTC/VRAM. 0:No, 1:RESET, 2:CRTC, 3:Auto(default)',13,10
	db	'	-i      Do not check machine',13,10
%endif
%if TOWNS
	db	'	-n      Do not load NSD driver',13,10
%endif
	db	'$'
msg_hex4 db	'####h',13,10,'$'

err_01e	db	'EMS Device Header is not found',13,10,'$'
err_01	db	'VCPI is not found',13,10,'$'
err_02	db	'VCPI error',13,10,'$'
err_03	db	'CPU mode not change',13,10,'$'
err_04	db	'XMS: driver not found',13,10,'$'
err_05	db	'XMS: XMS memory allocation failed',13,10,'$'
err_06	db	'XMS: XMS memory release failed',13,10,'$'
err_07	db	'XMS: XMS memory lock failed',13,10,'$'
err_10	db	'This free386 is incompatible (for ',MACHINE_STRING,' binary).',13,10
	db	'If you do not want to check the machine, ',
	db	'please execute with the -i option.',13,10,'$'
err_11	db	'CALL buufer (Real memory) allocate failed',13,10,'$'

err_xxh	db	'F386: Unknown error',13,10,'$'
err_21h	db	'F386: Protect memory is insufficient',13,10,'$'
err_22h	db	'F386: Can not read executable file',13,10,'$'
err_23h	db	'F386: Memory is insufficient to load executable file',13,10,'$'
err_24h	db	'F386: Unknown EXP header (Compatible: P3-flat model, MZ-header)',13,10,'$'
err_25h	db	'F386: Real memory heap overflow (*_malloc/*_calloc)',13,10,'$'
err_26h	db	'F386: INT stack (Protect <-> V86 stack) overflow',13,10,'$'
err_27h	db	'F386: INT stack (Protect <-> V86 stack) underflow',13,10,'$'
err_28h	db	'F386: File read error(int 21h fail)',13,10,'$'

	align	4
end_msg_table:	;*** 内部エラーコード(20h-) *** (00-1fh:欠番)
	dw	offset err_xxh	;欠番
	dw	offset err_21h
	dw	offset err_22h
	dw	offset err_23h
	dw	offset err_24h
	dw	offset err_25h
	dw	offset err_26h
	dw	offset err_27h
	dw	offset err_28h


