;******************************************************************************
; Free386 define
;******************************************************************************
;[TAB=8]
;
;==============================================================================
; Version setting
;==============================================================================
%define	VER_STRING	'Ver1.00'
%define RELEASE_DATE	'2024-09-19'
Major_ver	equ		01h
Minor_ver	equ		00h
F386_Date	equ		20240919h	;Release date

;==============================================================================
; Default build target
;==============================================================================
%ifndef BUILD_TARGET
		; if all of zero, for DOS general purpose.
%define	TOWNS		1	; for FM TOWNS binary
%define	PC_98		0	; for PC-9801/9821 binary
%define	PC_AT		0	; for PC/AT binary
%endif

;==============================================================================
; RELEASE or DEVELOP setting
;==============================================================================
%ifndef RELEASE
		; for DEVELOP build
INT_HOOK	equ	0	; Interrupt hook and register dump
INT_HOOK_RETV	equ	1	; 	with return value dump
INT_HOOK_AH	equ	0	; 	only AH value
INT_HOOK_AX	equ	0	; 	only AX value
INT_HOOK_CS	equ	0	; 	only CS value
INT_HOOK_EX_CS	equ	0	; 	exclude CS value
INT_HOOK_F386	equ	0	; (DANGER!) with Free386 CS's INT
PRINT_TO_FILE	equ	0	; int 21/ah=09h to DUMP_FILE file
PRINT_TSUGARU	equ	0	; int 21/ah=09h to Tsugaru(emulator) console
DUMP_DS_EDX	equ	1	; int 21h, AX=2510h-2511h, need PRINT_TSUGARU

%else
		; for RELEASE
INT_HOOK	equ	0
INT_HOOK_RETV	equ	0
INT_HOOK_AH	equ	0
INT_HOOK_AX	equ	0
INT_HOOK_CS	equ	0
INT_HOOK_EX_CS	equ	0
INT_HOOK_F386	equ	0
PRINT_TO_FILE	equ	0
PRINT_TSUGARU	equ	0
DUMP_DS_EDX	equ	0

%endif

%define	DUMP_FILE	'dump.txt'

%ifdef RELEASE
	%define	DATE_STRING	RELEASE_DATE
%else
	%define	DATE_STRING	'Build:',__?DATE?__
%endif

;==============================================================================
; Operation settings
;==============================================================================
EXP_EXT		equ	'.exp'	; Autocomplete extensions
MAX_RAM		equ 40000000h	; 1GB

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

_pool_for_paging equ	2	; pool RAM pages for paging (1page=4KB)
_call_buf_sizeKB equ	32	; call buffer size for 32bit<->16bit function
_resv_real_memKB equ	8	; reserved real memory (KB) for DOS
_user_cbuf_pages equ	4	; user call buffer (int 21h, AX=250Dh)
				; if set 0, this buffer same free386 internal

;==============================================================================
; General define
;==============================================================================
F386ERR		equ	0fch	; Free386 internal error code
CPU_Fault	equ	0fdh	; CPU fault        error code

WORK_size	equ	200h	; Universal work size, min 200h

GP_BUFFERS	equ	4	; number of general purpose buffers, max 32
GP_BUFFER_SIZE	equ	200h	; min 100h

V86_stack_size	equ	 200h	; byte
PM_stack_size	equ	 300h	; byte
VCPI_stack_size	equ	 100h	; VCPI call(to V86) dedicated stack

SW_stack_size	equ	180h	; CPU switch stack size
SW_max_nest	equ	4	; CPU switch max nest

LADR_HROOM_size	equ 0200000h	; 2MB, Head room for linear address expansion
LADR_UNIT	equ 0400000h	; 4MB, Memory address allocation unit

;==============================================================================
; Function call setting
;==============================================================================
int_21h_fn_MAX	equ	7fh	;int 21h function's maximum AH
DOSX_fn_MAX	equ	17h	;DOS-Extender function's maximum AL

F386_INT	equ	9ch	;Free386's INT
F386_INT_fn_MAX	equ	1fh	;Free386's INT maximum AH

INT_REGDUMP	equ	0ffh	; interrupt for user program register dump

;==============================================================================
; Selector setting
;==============================================================================
NULL_sel	equ	00h
VCPI_sel	equ	68h	;VCPI (68h, 70h, 78h)

GDTsize		equ	200h	;GDT (000h tp 1f8h)
LDTsize		equ	200h	;LDT (004h to 1fch)
IDTsize		equ	800h	;IDT (000h to 0ffh) / fixed
TSSsize		equ	80h	;TSS (min 68h byte)

LDT_load_sel	equ	28h	;LDT
TSS_load_sel	equ	80h	;TSS
LDT_sel		equ	30h	;LDT access
GDT_sel		equ	38h	;GDT access
IDT_sel		equ	50h	;IDT access
TSS_sel		equ	88h	;TSS access

ALLMEM_sel	equ	40h	;ALL RAM selector
DOSMEM_sel	equ	60h	;DOS 1MB memory
DOSMEMsize	equ	110000h	;1MB + 64KB(HMA)
	; DOSMEM_sel is used for read/write to DOS memory, so 1.1MB is required.
	; In RUN386.exe, size of DOSMEM_sel is 1MB

F386_cs		equ	08h	;Free386's CS
F386_ds		equ	10h	;Free386's DS
F386_cs286	equ	18h	;Free386 CS (286 attribute / not use)
F386_ds286	equ	20h	;Free386 DS (286 attribute / not use)

PSP_sel1	equ	24h	;PSP
PSP_sel2	equ	04h	;
DOSENV_sel	equ	2ch	;DOS ENV
DOSMEM_Lsel	equ	34h	;DOS 1MB memroy

IntVectors	equ	100h	;Interrupt vectors, fixed

;==============================================================================
;for BUILD_TARGET macro
;==============================================================================
%ifidni BUILD_TARGET,TOWNS
	%define	TOWNS	1

%elifidni BUILD_TARGET,PC_98
	%define	PC_98	1
%elifidni BUILD_TARGET,PC98
	%define	PC_98	1
%elifidni BUILD_TARGET,98
	%define	PC_98	1

%elifidni BUILD_TARGET,PC_AT
	%define	PC_AT	1
%elifidni BUILD_TARGET,AT
	%define	PC_AT	1

%elifidni BUILD_TARGET,gen
	;
%elifidni BUILD_TARGET,general
	;
%elifdef BUILD_TARGET
	%error Unknown build target
%endif

%ifndef TOWNS
	%define	TOWNS	0
%endif
%ifndef PC_98
	%define	PC_98	0
%endif
%ifndef PC_AT
	%define	PC_AT	0
%endif

;==============================================================================
;Machine type setting
;==============================================================================
;------------------------------------------------------------------------------
;for FM TOWNS
;------------------------------------------------------------------------------
%if TOWNS

MACHINE_CODE	equ	20h	;FM TOWNS

%define	MACHINE_STRING	'FM TOWNS'
%define	Free386_API	'f386_fmt.api'

%define PATCH_UNZ_BUG		;patch for emulator UNZ's bug
%define XMS_EMULATOR

INIT_KEY_BIOS	equ	1	;終了時に key-BIOS を初期化する

TBIOS_cs	equ	110h	;T-BIOS の code セレクタ
TBIOS_ds	equ	118h	;T-BIOS の data セレクタ

NSDD_stra_adr	equ	06h	;strategy エントリーのあるオフセット
NSDD_intr_adr	equ	08h	;interruptエントリーのあるオフセット
NSDD_sleep	equ	0c0h	; intr/sleep  request
NSDD_wakeup	equ	0c1h	; intr/wakeup request

XMS_HANDLES_MAX	equ	10h	;XMS handles max

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

%define	MACHINE_STRING	'PC-98'
%define	Free386_API	'f386_98.api'	;機種固有APIのファイル名

VRAM_16padr	equ 0E00A8000h	;16色VRAM を配置する物理アドレス
VRAM_CGW	equ 0E00A4000h	;CGW を配置するリニアアドレス
VRAM_TEXT	equ 0E00A0000h	;CGW を配置するリニアアドレス
STOP_GVRAM	equ	0	;終了処理でグラフィック画面の表示をoffする

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

VESA_DISABLE	equ	1	; Disable VESA

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

HW_INT_MASTER	equ	 08h	; master
HW_INT_SLAVE	equ	 70h	; slave
I8259A_ISR_M	equ	 20h	; service register
I8259A_ISR_S	equ	0a0h	;
I8259A_IMR_M	equ	 21h	; mask register
I8259A_IMR_S	equ	0a1h	;

%endif

;------------------------------------------------------------------------------
;for General DOS machine
;------------------------------------------------------------------------------

%if (TOWNS + PC_98 + PC_AT) = 0

MACHINE_CODE	equ	00h

%define	MACHINE_STRING	'MS-DOS'
%define	Free386_API	'f386_all.api'	; dummy

%define DOS_GENERAL_PURPOSE	1
%define USE_VCPI_8259A_API

HW_INT_MASTER	equ	100h	; dummy, do not set other value
HW_INT_SLAVE	equ	100h	; dummy, do not set other value

%endif
