;******************************************************************************
; Free386 define
;******************************************************************************
;[TAB=8]
;
;==============================================================================
; Version setting
;==============================================================================
%define	VER_STRING	'Ver0.81dev 2023-12-xx'
Major_ver	equ		00h
Minor_ver	equ		80h
F386_Date	equ		20231205h	;Release date

;==============================================================================
; RELEASE and DEBUG setting
;==============================================================================
%ifndef AUTO_RELEASE
		; Target Machine / If all of zero, for DOS general purpose.
TOWNS		equ	1	; for FM TOWNS binary
PC_98		equ	0	; for PC-9801/9821 binary
PC_AT		equ	0	; for PC/AT binary

		; for DEVELOP build
INT_HOOK	equ	0	; Interrupt hook and register dump
INT_HOOK_RETV	equ	1	; 	with return value dump
INT_HOOK_AH	equ	0	; 	only AH value
INT_HOOK_CS	equ	0	; 	only CS value
INT_HOOK_EX_CS	equ	0	; 	exclude CS value
INT_HOOK_F386	equ	0	; (DANGER!) with Free386 CS's INT
PRINT_TO_FILE	equ	0	; int 21/ah=09h to DUMP_FILE file
PRINT_TSUGARU	equ	0	; int 21/ah=09h to Tsugaru(emulator) console

%else
		; for RELEASE
INT_HOOK	equ	0
INT_HOOK_RETV	equ	0
INT_HOOK_AH	equ	0
INT_HOOK_CS	equ	0
INT_HOOK_EX_CS	equ	0
INT_HOOK_F386	equ	0
PRINT_TO_FILE	equ	0
PRINT_TSUGARU	equ	0

%endif

INT_REGDUMP	equ	0ffh	; interrupt for user program register dump

%define	DUMP_FILE	'dump.txt'

;==============================================================================
; Operation settings
;==============================================================================
EXP_EXT		equ	'.exp'	; Autocomplete extensions
MAX_RAM		equ 10000000h	; 1GB

USE_MZ_EXP	equ	1	; support MP Header EXP file.
CHECK_EMS	equ	1	; check EMS installed
USE_XMS20	equ	0	; support XMS Ver2.0 (not need)

Restore8259A	equ	1	; Restore hardware interrupt mask on end
RestoreRealVec	equ	1	; Restore real mode interrupt vectors on end

	;---------------------------
	; Default operation setting
	;---------------------------
_show_title	equ	1	; show Free386's title
_verbose	equ	0	; verbose
_search_PATH386	equ	1	; search PATH386 for target EXP file
_search_PATH	equ	0	; search PATH    for target EXP file

_check_MACHINE	equ	1	; binary machine check
_reset_CRTC	equ	3	; CRTC/VRAM initialization settings at end
				;	0 = no reset
				;	1 = force reset
				;	2 = reset only CRTC
				;	3 = auto
				; Not support PC/AT machine.

_pool_for_paging equ	8	; pool RAM pages for paging (1page=4KB)
_call_buf_sizeKB equ	32	; call buffer size for 32bit<->16bit function
_resv_real_memKB equ	32	; reserved real memory (KB) for DOS

_user_cbuf_pages equ	8	; call buffer for client (int 21, AX=250Dh)
				; if set 0, user call buffer same internal

;==============================================================================
; General define
;==============================================================================
F386ERR		equ	0fch	; Free386 internal error code
CPU_Fault	equ	0fdh	; CPU fault        error code

WORK_size	equ	200h	; Universal work size

GP_BUFFERS	equ	4	; number of general purpose buffers, max 32
GP_BUFFER_SIZE	equ	400h	; 1KB

V86_stack_size	equ	 200h	; byte
PM_stack_size	equ	 380h	; byte
VCPI_stack_size	equ	  80h	; VCPI call(to V86) dedicated stack

SW_stack_size	equ	200h	; CPU switch stack size
SW_max_nest	equ	4	; CPU switch max nest

LADR_UNIT	equ	400000h	; Memory address allocation unit
LADR_ROOM_size	equ	200000h	; Room for memory address expansion

;==============================================================================
; Function call setting
;==============================================================================
int_21h_MAXF	equ	7fh	;int 21h function's maximum AH
DOS_Ext_MAXF	equ	17h	;DOS-Extender function's maximum AL

F386_INT	equ	9ch	;Free386's INT
F386_INT_MAXF	equ	1fh	;Free386's INT maximum AH

;==============================================================================
; Selector setting
;==============================================================================
NULL_sel	equ	00h
VCPI_sel	equ	68h	;VCPI (68h, 70h, 78h)

GDTsize		equ	200h	;GDT (000h tp 1f8h)
LDTsize		equ	200h	;LDT (004h to 1fch)
IDTsize		equ	800h	;IDT (000h to 0ffh) / fixed
TSSsize		equ	80h	;TSS (min 68h byte)

LDT_sel		equ	28h	;LDT
LDT_RW		equ	30h	;LDT access
GDT_RW		equ	38h	;GDT access
IDT_RW		equ	50h	;IDT access
TSS_sel		equ	80h	;TSS
TSS_RW		equ	88h	;TSS access

ALLMEM_sel	equ	40h	;ALL RAM selector
DOSMEM_sel	equ	60h	;DOS 1MB memory
DOSMEMsize	equ	110000h	;1MB + 64KB (HMA)

F386_cs		equ	08h	;Free386's CS
F386_ds		equ	10h	;Free386's DS
F386_cs2	equ	18h	;Free386 CS (286 attribute / not use)
F386_ds2	equ	20h	;Free386 DS (286 attribute / not use)

PSP_sel1	equ	24h	;PSP
PSP_sel2	equ	04h	;
DOSENV_sel	equ	2ch	;DOS ENV
DOSMEM_Lsel	equ	34h	;DOS 1MB memroy

IntVectors	equ	100h	;Interrupt vectors, fixed

;==============================================================================
;Machine type setting
;==============================================================================
;------------------------------------------------------------------------------
;for FM TOWNS
;------------------------------------------------------------------------------
%if TOWNS

MACHINE_CODE	equ	20h	;FM TOWNS

%define	MACHINE_STRING	'FM TOWNS'
%define	Free386_API	'f386_fmt.api'	;機種固有APIのファイル名

INIT_KEY_BIOS	equ	1	;終了時に key-BIOS を初期化する

TBIOS_cs	equ	110h	;T-BIOS の code セレクタ
TBIOS_ds	equ	118h	;T-BIOS の data セレクタ

NSDD_max	equ	20	;NSD Driverの最大対応数
NSDD_stra_adr	equ	06h	;strategy エントリーのあるオフセット
NSDD_intr_adr	equ	08h	;interruptエントリーのあるオフセット
NSDD_sleep	equ	0c0h	; intr/sleep  request
NSDD_wakeup	equ	0c1h	; intr/wakeup request

enable_INTR	equ	1	;プロテクトモードでの割り込みを許可する
HW_INT_MASTER	equ	40h	;マスタ：ハードウェア割り込み先頭
HW_INT_SLAVE	equ	48h	;スレーブ
I8259A_ISR_M	equ	00h	;サービスレジスタ
I8259A_ISR_S	equ	10h	;
I8259A_IMR_M	equ	02h	;マスクレジスタ
I8259A_IMR_S	equ	12h	;

%endif

;------------------------------------------------------------------------------
;for PC-9821/9801
;------------------------------------------------------------------------------
%if PC_98

MACHINE_CODE	equ	10h	;PC-9801/9821

%define	MACHINE_STRING	'PC-9801/9821'
%define	Free386_API	'f386_98.api'	;機種固有APIのファイル名

VRAM_16padr	equ 0E00A8000h	;16色VRAM を配置する物理アドレス
VRAM_CGW	equ 0E00A4000h	;CGW を配置するリニアアドレス
VRAM_TEXT	equ 0E00A0000h	;CGW を配置するリニアアドレス
STOP_GVRAM	equ	0	;終了処理でグラフィック画面の表示をoffする

enable_INTR	equ	1	;プロテクトモードでの割り込みを許可する
HW_INT_MASTER	equ	08h	;マスタ：ハードウェア割り込み先頭
HW_INT_SLAVE	equ	10h	;スレーブ
I8259A_ISR_M	equ	00h	;サービスレジスタ
I8259A_ISR_S	equ	08h	;
I8259A_IMR_M	equ	02h	;マスクレジスタ
I8259A_IMR_S	equ	0ah	;

%endif

;------------------------------------------------------------------------------
;for PC/AT
;------------------------------------------------------------------------------
%if PC_AT

MACHINE_CODE	equ	30h	; PC/AT

%define	MACHINE_STRING	'PC/AT'
%define	Free386_API	'f386_at.api'	; API file

VESA_buf_sel	equ	148h	; VESA-BIOS buffer selector
VESA_buf_size	equ	1	; VESA-BIOS buffer size (page / 1=4kb)
VESA_call_adr	equ	0ffc0h	; VESA-BIOS / call VESA_cs:VESA_call_adr

VESA_cs		equ	150h	; VESA-BIOS code selector
VESA_ds		equ	158h	; VESA-BIOS data selector (cs alias)
VESA_ds2	equ	160h	; VESA-BIOS data selector 2 (needs 600h)
VESA_A0		equ	168h	; VESA-BIOS selector A0000h (64kb)
VESA_B0		equ	170h	; VESA-BIOS selector B0000h (64kb)
VESA_B8		equ	178h	; VESA-BIOS selector B8000h (32kb)

VRAM_padr	equ 0e6000000h	; VRAM physical address
VRAM_pages	equ	200h	; size=16MB / [page unit] ex)100h=8MB
VRAM_sel	equ	120h	; VRAM selector (Change with at.asm)

enable_INTR	equ	1	; Enable hardware interrrupt
HW_INT_MASTER	equ	 08h	; master
HW_INT_SLAVE	equ	 70h	; slave
I8259A_ISR_M	equ	 20h	; service register
I8259A_ISR_S	equ	0a0h	;
I8259A_IMR_M	equ	 21h	; mask register
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

MACHINE_CODE	equ	00h

%define	MACHINE_STRING	'MS-DOS'
%define	Free386_API	'f386_all.api'	; dummy

enable_INTR	equ	0	; Do not use hardware interrupt
HW_INT_MASTER	equ	0f0h	; dummy
HW_INT_SLAVE	equ	0f0h	; dummy

%endif

