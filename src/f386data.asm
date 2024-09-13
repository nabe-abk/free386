;******************************************************************************
;　Free386 data
;******************************************************************************
;==============================================================================
; Const
;==============================================================================
env_PATH386	db	'PATH386',0	; ENV name for exp file search
env_PATH	db	'PATH',0	;

default_API	db	Free386_API,0	; API file name

;==============================================================================
; General variable
;==============================================================================
err_level	db	0		; DOS error level
f386err		db	0		; Free386 internal error level
cpu_is_386sx	db	0		; CPU is 386SX
init_machine16	db	0		; initalized machine on 16bit
init_machine32	db	0		; initalized machine on 32bit
use_vcpi	db	1		; VCPI enviroment

%ifdef USE_VCPI_8259A_API
vcpi_8259m	db	0		; 8259A Master interrupt number
vcpi_8259s	db	0		; 8259A Slave  interrupt number
%endif

	align	4
pharlap_version		db	'12aJ'	; Ver 1.2aj
exp_name_adr		dd	0	; file name string, no null terminate
exp_name_len		dd	0	; file name length
exp_name_include_path	dd	0	; exp name include ":" or "\"
exp_name_fname_offset	dd	0	; file name offset exclude "path"

;==============================================================================
; Buffer information
;==============================================================================

work_adr	dd	0		; universal work (min:200h)

	; file and string buffer
call_buf_used	dd	0		; used flag
call_buf_size	dd	0		; byte
call_buf_adr16	dw	0		; offset
call_buf_seg16	dw	0		; segment
call_buf_adr32	dd	0		; address

user_cbuf_adr16	dw	0		; offset
user_cbuf_seg16	dw	0		; segment
user_cbuf_ladr	dd	0		; linear address

;--------------------------------------------------------------------
; memory information
;--------------------------------------------------------------------
	align	4
safe_stack_adr	dd	0		;V86 モード切り換え時のみ
		dw	F386_ds		;　使用するスタック

PM_stack_adr	dd	0		;プロテクトモード時のスタック
		dw	F386_ds		;
V86_cs		dw	0,0		;V86モード時 cs
V86_sp		dw	0,0		;V86モード時 sp

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

max_EMB_free	dd	0		;最大の EMB 空きメモリサイズ    (Kbyte)
total_EMB_free	dd	0		;トータルの EMB 空きメモリサイズ(Kbyte)

;--------------------------------------------------------------------
;----- プロテクトメモリ管理情報 -------------------------------------
free_linear_adr	dd	0		;未定義(未使用)リニアアドレス (最低位)
free_RAM_padr	dd	0		;空き先頭物理RAMページアドレス
free_RAM_pages	dd	0		;利用可能な物理RAMページ数 (4KB単位)

	;以下 VCPI からと関連の濃いもの
all_mem_pages	dd	0		;物理メモリ、総メモリページ数
vcpi_mem_pages	dd	0		;VCPI の管理するメモリページ数

page_dir_ladr		dd	0	;page directory linear address
page_dir_seg		dw	0,0	;page directory's dos segment
page_tables_in_dos	dd	2	;Number of page tables in dos memory

;--------------------------------------------------------------------
;----- データ領域 ---------------------------------------------------
;
	align	4
top_ladr	dd	0		;プログラム先頭リニアアドレス
intr_mask_org	dw	0		;8259A オリジナル値バックアップ

DTA_off		dd	80h		;DTA 初期値
DTA_seg		dw	PSP_sel1,0	;

;----- データ領域２ -------------------------------------------------
;
	align	4
LGDT_data	dw	GDTsize-1	;GDT リミット
		dd	0		;    リニアアドレス
LIDT_data	dw	IDTsize-1	;IDT リミット
		dd	0		;    リニアアドレス

RM_LIDT_data	dw	3ffh		;limit
		dd	0		;address

DOS_int24h_adr	dw	0		;DOS int 24h CS:IP
DOS_int24h_seg	dw	0		;
VCPI_entry	dd	0		;VCPI サービスエントリ
		dw	VCPI_sel	;VCPI セレクタ


	;/// リアルモードベクタ設定用データ領域 ////////
	align	4
RVects_flag_tbl	resb	IntVectors/8	;書き換えフラグ テーブル
RVects_save_adr	dd	0		;リアルモードベクタ保存のアドレス

;--------------------------------------------------------------------
; VCPI data
;--------------------------------------------------------------------
	align	4
to_PM_data_ladr	dd	0	; to_PM_data's linear address

to_PM_data:	; V86 -> Protect Mode structure
to_PM_CR3	dd	0
to_PM_GDTR	dd	0
to_PM_IDTR	dd	0
to_PM_LDTR	dw	LDT_load_sel
to_PM_TR	dw	TSS_load_sel
to_PM_EIP	dd	0
to_PM_CS	dw	F386_cs

;==============================================================================
; Messages
;==============================================================================
P_title	db	'Free386(386|DOS-Extender) for '
	db	MACHINE_STRING
	db	' - ', VER_STRING,' ',DATE_STRING
	db	' (C)nabe@abk',13,10,'$'
seg_msg	db	'Code segment: '
seg_hex	db	'####',13,10,'$'

end_mes	db	'Finish',13,10,'$'

msg_01	db	"*** Free386 memroy information ***",13,10
	db	'	['
msg_all_mem_type db     'VCPI'
	db		    '] Physical Memory size = ####### KB',13,10
	db	'	[XMS]  Allocate Ext Memory  = ####### KB (####_#### - ####_####)',13,10
	db	'	[DOS]  Allocate DOS Memory  = ####### KB (####_#### - ####_####)',13,10
	db	'	[DOS]  Reserved DOS Memory  =    #### KB',13,10
	db	'$'
msg_02	db	'	code and static	: 0100 - #### / cs=ds=####',13,10
	db	'	all heap memory	: #### - ffff / ##### byte',13,10
	db	'	free heap memory: #### - #### / ##### byte',13,10
	db	'	real vecs backup: #### - ####',13,10
	db	'	16bit int hook  : #### - ####',13,10
	db	'	GDT,LDT,IDT,TSS	: #### - #### - #### - #### - ####',13,10
	db	'	call buffer     : #### - #### / ##### byte',13,10
	db	'	general work mem: #### - ####',13,10
	db	'	CPU switch stack: #### - #### / ##### byte * ','0' + SW_max_nest,13,10
	db	'	safe,32,16 stack: #### - #### - #### - ffff',13,10
	db	'	user call buffer: ####:#### - / ##### byte',13,10
	db	'$'

msg_05	db	'Load file name = $'
msg_06	db	'Found XMS 2.0',13,10,'$'
msg_07	db	'Found XMS 3.0',13,10,'$'
msg_08	db	'Found VCPI',13,10,'$'
msg_10	db	'Usage: free386 <target.exp>',13,10
	db	13,10
	db	'	-v	Verbose (memory information and other)',13,10
	db	'	-vv	More verbose (internal memory information)',13,10
	db	"	-q	Do not output Free386's title and this help",13,10
	db	'	-p	Search .exp file from PATH (with default from PATH386)',13,10
	db	'	-m	Set reserved DOS memory to 0 byte for allocate more memory',13,10
	db	'	-2	Set PharLap version is 2.2 (ebx=20643232h)',13,10
%if MACHINE_CODE
	db	'	-c?     Reset CRTC/VRAM. 0:No, 1:RESET, 2:CRTC, 3:Auto(default)',13,10
	db	'	-i	Do not check machine',13,10
%endif
%if TOWNS
	db	'	-n	Do not load NSD driver',13,10
%endif
	db	'$'

err_head	db	'[F386] $'
err_00		db	'Unknown error',13,10,'$'
err_xms_free	db	'XMS: XMS memory release failed',13,10,'$'

err_msg_table:
_e01	db	'Do not execute free386.exe (please run free386.com)',13,10,'$'
_e02	db	'Incompatible binary! This binary for ',MACHINE_STRING,'.',13,10
	db	'If you do not want to check the machine, please execute with the -i option.',13,10,'$'
_e03	db	'EMS Device Header not found',13,10,'$'
_e04	db	'VCPI not found',13,10,'$'
_e05	db	'XMS driver not found',13,10,'$'
_e06	db	'XMS memory allocation failed',13,10,'$'
_e07	db	'XMS memory lock failed',13,10,'$'
_e08	db	'VCPI: Failed to get protected mode interface',13,10,'$'
_e09	db	'VCPI: Failed to change CPU to protected mode',13,10,'$'
_e10	db	'VCPI: Failed to get phisical address of page',13,10,'$'

; error message for memory allocation
_e11	db	'Memory allocation failed, not enough heap memory',13,10,'$'
_e12	db	'CALL buffer allocation failed',13,10,'$'
_e13	db	'Page table memory (real memory) allocation failed',13,10,'$'
_e14	db	'Not enough stack for switch CPU mode',13,10,'$'
_e15	db	'Failure to free stack memory for switch CPU mode',13,10,'$'

_e16	db	'User call buufer allocation failed',13,10,'$'
_e17_20	db	'$$$$'

; error message for protect mode
_e21	db	'Can not read executable file',13,10,'$'
_e23	db	'File read error (int 21h failed)',13,10,'$'
_e22	db	'Memory is insufficient to load executable file',13,10,'$'
_e24	db	'Unknown EXP header (Compatible: P3-flat model, MZ-header)',13,10,'$'
_e25	db	0,'Abort!',13,10,'$'		; output only when verbose flag

