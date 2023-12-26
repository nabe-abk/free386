;******************************************************************************
; V86 <-> Protect mode routines
;******************************************************************************
;[TAB=8]
;
%include	"macro.inc"
%include	"f386def.inc"

%include	"free386.inc"
%include	"memory.inc"

;******************************************************************************
; global symbols
;******************************************************************************
global	V86int_table_adr

global	cv86_ds
global	cv86_es
global	cv86_fs
global	cv86_gs

global	cv86_copy_stack
global	cv86_copy_size

global	call32_from_V86	; use by int 21h ax=250dh and towns.asm

;******************************************************************************
seg16	text class=CODE align=4 use16
;******************************************************************************
;==============================================================================
; initalize
;==============================================================================
proc2 setup_cv86
	;//////////////////////////////////////////////////
	; init cv86/cf32 stack
	;//////////////////////////////////////////////////
	mov	ax, cs
	mov	[cv86_cs], ax
	mov	[cv86_ss], ax
	mov	[cv86_ds], ax
	mov	[cv86_es], ax
	mov	[cv86_fs], ax
	mov	[cv86_gs], ax

	;//////////////////////////////////////////////////
	; make realmode to Protect mode entries
	;//////////////////////////////////////////////////
	mov	ax, IntVectors *4
	call	heap_malloc
	mov	[V86int_table_adr],di

	mov	dx, di
	add	dx, byte 3		; "e8 xx xx" is 3byte
	mov	[V86int_table_top],dx	; int 0's return address

	; Routine code:
	;	e8 xx xx	call int_buf
	;	90		nop
	;
	mov	bl,0e8h			;call opcode
	mov	bh, 90h			;NOP  opcode
	mov	ax,offset int_from_V86	;call address
	sub	ax,dx			;to relative address

	mov	cx, IntVectors
	mov	bp, 4

.loop:
	mov	[di  ],bl		; call
	mov	[di+1],ax		; <r_adr>
	mov	[di+3],bh		; NOP
	add	di,bp			; +4
	sub	ax,bp			; -4
	loop	.loop

	ret

;******************************************************************************
seg32	text32 class=CODE align=4 use32
;******************************************************************************
;******************************************************************************
; call V86 main
;******************************************************************************
; in	cli
;
; stack	+00h	ret address
;	+04h	option
;			bit 0	int
;			bit 1	clear ds,es
;	+08h	cs:ip / int number(00h-ffh)
;
proc4 call_V86_clear_stack
	start_sdiff
	push_x	gs
	push_x	fs
	push_x	es
	push_x	ds
	pushf_x

	push	F386_ds
	pop	ds
	mov	[tmp_eax], eax
	mov	[tmp_ebx], ebx
	mov	[tmp_ecx], ecx
	mov	ecx, [esp + .sdiff + 04h]	; option flags
	mov	ebx, [esp + .sdiff + 08h]	; call adr OR int number

	;--------------------------------------------------
	; int or far call?
	;--------------------------------------------------
	test	cl, O_CV86_INT
	mov	ch, 9Dh				; "nop"(90h) to "popf"(9Dh) for far call
	jz	.far_call

	push	DOSMEM_sel
	pop	fs
	mov	ebx, fs:[ebx*4]			; load interrupt vector
	mov	ch, 90h				; "popf"(9Dh) to "nop"(90h) for int

.far_call:
	mov	[call_V86_adr], ebx		; save call adr
	mov	[.in_V86_popf_opcode],ch	; write popf OR nop

	;--------------------------------------------------
	; clear V86 ds, es
	;--------------------------------------------------
	test	cl, O_CV86_CLSEG		; check option flag
	jz	short .not_clear_ds_es

	mov	ebx, [cv86_cs]
	mov	[cv86_ds], ebx
	mov	[cv86_es], ebx
.not_clear_ds_es:

	;--------------------------------------------------
	; alloc V86 stack
	;--------------------------------------------------
	call	alloc_sw_stack_32	; eax <- pointer 

	mov	ebx, esp
	push	ss
	pop	es			; es:ebx = ss:esp

	push	ds
	pop	ss
	mov	esp, eax		; switch to V86 stack

	;--------------------------------------------------
	; save to V86 stack
	;--------------------------------------------------
	push	es			; protect mode SS
	push	ebx			; protect mode ESP

	;--------------------------------------------------
	; copy to V86 stack
	;--------------------------------------------------
	mov	ecx, [cv86_copy_size]
	test	ecx, ecx
	jz	.no_stack_copy

	mov	eax, [cv86_copy_stack]
	add	eax, ecx			; copy start
.copy_loop:
	sub	eax, 4
	push	dword es:[eax]
	sub	ecx, 4
	ja	.copy_loop
	sub	esp, ecx			; adjust pointer

	xor	eax, eax
	mov	[cv86_copy_size], eax		; copy size set 0

.no_stack_copy:
	;--------------------------------------------------
	; push to V86 stack, restore register
	;--------------------------------------------------
	push	word es:[ebx]			; flags
	push	dword [tmp_eax]			; eax

	mov	ebx, [tmp_ebx]
	mov	ecx, [tmp_ecx]

	; V86 stack
	;	+00h d	eax
	;	+04h w	flags
	;	+06h -	<stack copy data> // any size
	;	+xx   d	protect mode caller esp
	;	+xx+4 d	protect mode caller  ss

	;--------------------------------------------------
	; jmp to V86
	;--------------------------------------------------
	mov	[cv86_esp], esp		;save V86 sp
	lss	esp,[cv86_stack_adr]	;PM -> V86 stack structure

	mov	dword [cv86_eip], .in_V86

	mov	ax,0de0ch		;VCPI function 0ch / to V86 mode
	call 	far [cs:VCPI_entry]	;VCPI far call

;--------------------------------------------------------------------
BITS	16
proc4 .in_V86
	pop	eax
.in_V86_popf_opcode:
	popf
	call	far [cs:call_V86_adr]

	pushfd
	push	eax
	push	esi

	cli
	mov	[cs:cv86_ds], ds
	push	cs
	pop	ds
	mov	[cv86_es], es
	mov	[cv86_fs], fs
	mov	[cv86_gs], gs

	;--------------------------------------------------
	; jmp to Protect mode
	;--------------------------------------------------
	mov	[tmp_esp], sp
	mov	d [to_PM_EIP],offset .ret_PM

	mov	esi,[to_PM_data_ladr]
	mov	ax,0de0ch
	int	67h			;VCPI call

;--------------------------------------------------------------------
BITS	32
proc4 .ret_PM
	mov	ax, F386_ds
	mov	ds, ax
	lss	esp, [tmp_esp]		;switch to V86 stack

	; V86 stack
	;	+00h d	esi
	;	+04h d	eax
	;	+08h d	eflags
	;	+0ch -	<stack copy data>
	;	+xx   d	protect mode caller esp
	;	+xx+4 d	protect mode caller  ss
	;	-------------------------------- stack bottom
	
	pop	esi			; recovery esi
	pop	dword [tmp_eax]		; pop eax
	mov	[tmp_ebx], ebx
	pop	eax			; V86 eflags

	; calc current switch stack bottom pointer
	mov	ebx, [sw_stack_bottom]
	add	ebx, SW_stack_size - 8
	lss	esp,[ebx]		; load caller stack

	call	free_sw_stack_32	; free V86 stack // no argument

	; caller stack
	;	-14h d	eflags
	;	-10h d	ds
	;	-0ch d	es
	;	-08h d	fs
	;	-04h d	gs
	; stack	+00h	ret address
	;	+04h	option
	;	+08h	cs:ip / int number(00h-ffh)

	pop_x	ebx			; caller eflags
	and	eax, 000000fffh		; V86    eflags mask system bits
	and	ebx, 0fffff000h		; caller eflags mask status bits
	or	ebx, eax

	push	ebx
	popf
	mov	eax, [tmp_eax]
	mov	ebx, [tmp_ebx]

	pop_x	ds
	pop_x	es
	pop_x	fs
	pop_x	gs
	end_sdiff

	ret	8	; remove 8byte stack

;------------------------------------------------------------------------------
; call V86 support routine
;------------------------------------------------------------------------------
; stack
;	+00h d Interrupt number
;	+04h d eip
;	+08h d cs
;	+0ch d eflags
;
proc4 call_V86_int21_iret
	push	21h

proc1  call_V86_int_iret
	btc	dword [esp+0ch], 0	; set caller carry status

	push	O_CV86_INT | O_CV86_CLSEG
	call	call_V86_clear_stack

	iret_save_cy
	iret

	; for hardware interrupt
proc4 call_V86_HW_int_iret
	push	O_CV86_INT
	call	call_V86_clear_stack
	iret

proc4	all_flags_save_iret	; exclude IF
	xchg	[esp+8], eax

	push	ebx
	pushf
	pop	ebx
	and	eax, 0fffff200h
	and	ebx, 1101_1111_1111b
	or	eax, ebx
	pop	ebx

	xchg	[esp+8], eax
	iret


;******************************************************************************
seg16	text
;******************************************************************************
;******************************************************************************
; Interrupt for 32bit mode from V86
;******************************************************************************
; stack	+00h	internal caller IP from V86int_table
;	+02h	original caller IP
;	+04h	original caller CS
;	+06h	flags
;
BITS	16
proc4 int_from_V86_new
	push	ds	;4
	push	es	;3
	push	fs	;2
	push	gs	;1
	push	eax
	push	esi	; 10h byte stack push

	push	cs
	pop	ds

	;--------------------------------------------------
	; calc interrupt number
	;--------------------------------------------------
	mov	si,sp
	mov	ax,ss:[si + 10h]	;return EIP

	sub	ax,[V86int_table_top]	;int 0's address
	shr	ax,2			;div 4
;	mov	[.int_opcode +1], al	;rewrite int opcode imm

	;--------------------------------------------------
	; change protect mode
	;--------------------------------------------------
;	mov   d [to_PM_EIP], .in_PM

	mov	esi,[to_PM_data_ladr]
	mov	ax,0de0ch
	int	67h

;--------------------------------------------------------------------
proc4 int_from_V86
	push	ds	;4
	push	es	;3
	push	fs	;2
	push	gs	;1

	push	cs			;
	pop	ds			;ds 設定
	mov	[save_eax],eax		;eax セーブ
	mov	[save_esi],esi		;esi
	mov	[save_esp],esp
	mov	[save_ss] ,ss

	;-------------------------------
	;int 番号の算出
	;-------------------------------
	mov	ax,ss			;
	mov	fs,ax			;fs:si = ss:sp
	mov	si,sp			;

	mov	ax,[fs:si + 2*4]	;call 元アドレス
	sub	ax,[V86int_table_top]	;登録番号 0 から (CPU Int 処理と同じ
	shr	ax,2			;4 で割る         int.asm 参照)
	mov	[.int_no], al		;プロテクト時の呼び出し番号として記録

	mov   d [to_PM_EIP],offset .32	;呼び出しラベル

	mov	esi,[to_PM_data_ladr]	;モード切替え構造体
	mov	ax,0de0ch		;to プロテクトモード
	int	67h			;VCPI call


	align	4
	;*** プロテクトモードからの復帰ラベル ******
.ret_PM:
	mov	eax,[save_eax]		;eax 復元
	mov	esi,[save_esi]		;esi

	pop	gs
	pop	fs
	pop	es
	pop	ds
	add	sp,byte 2		;call の戻りスタック除去
	iret



BITS	32
;--------------------------------------------------------------------
;・プロテクトモード
;--------------------------------------------------------------------
	align	4
.32:
	mov	eax,F386_ds		;
	mov	  ds,ax			;ds ロード
	mov	  es,ax			;
	mov	  fs,ax			;
	mov	  gs,ax			;

	lss	esp,[PM_stack_adr]	;専用スタックロード
	;call	alloc_sw_stack_32	;スタック領域確保

	push	d [save_ss]		;リアルモードスタック
	push	d [save_esp]

	mov	eax,[save_eax]		;eax 復元
	mov	esi,[save_esi]		;esi

	push	ds
	db	0cdh			;int 命令
.int_no	db	 00h
	pop	ds

	cli
	mov	[save_eax], eax		;eax 保存
	mov	[save_esi], esi		;esi

	pop	d [save_esp]		;リアルモードスタック
	pop	d [save_ss]

	;call	free_sw_stack_32	;スタック開放

	mov	eax,[V86_cs]		;V86時 cs,ds
	push	eax			;** V86 gs
	push	eax			;** V86 fs
	push	eax			;** V86 ds
	push	eax			;** V86 es
	push	d [save_ss ]		;** V86 ss
	push	d [save_esp]		;** V86 sp
	pushfd				;eflags
	push	eax			;** V86 CS を記録
	push	d (offset .ret_PM)	;** V86 IP を記録

	mov	ax,0de0ch		;VCPI function 0ch / to V86 mode
	call 	far [VCPI_entry]	;VCPI far call



;******************************************************************************
; far call protect mode routeine from V86
;******************************************************************************
; int 21h, AX=250Dh routine
;
;
BITS	16
proc1 call32_from_V86.fail
	pop	ds
	popf
	pop	eax
	pop	esi
	retf

proc4 call32_from_V86
	push	esi
	push	eax
	pushf
	push	ds

	push	cs
	pop	ds

	call	alloc_sw_stack_16
	test	ax, ax
	jz	.fail

	;--------------------------------------------------
	; save register to switch stack
	;--------------------------------------------------
	cli
	mov	si, [sw_stack_bottom]	; get current swtich stack top
	xor	ax, ax
	pop	word [si]		; save ds
	mov	[si+02h], es
	mov	[si+04h], fs
	mov	[si+06h], gs
	pop	 word [si+1ch]		; flags
	pop	dword [si+10h]		; eax
	pop	dword [si+14h]		; esi
	pop	dword [si+18h]		; return cs:ip

	;--------------------------------------------------
	; analyze stack parameter
	;--------------------------------------------------
	pop	dword cs:[cf32_target_eip]
	pop	 word cs:[cf32_target_cs]

	pop	eax		; selector structure pointer
	test	eax, eax
	jz	.default

	push	ebx
	mov	bx, ax
	shr	eax, 16
	mov	es, ax

	mov	ax, es:[bx + 06h]
	mov	[cf32_ds_32], ax
	mov	ax, es:[bx + 04h]
	mov	[cf32_es_32], ax
	mov	ax, es:[bx + 02h]
	mov	[cf32_fs_32], ax
	mov	ax, es:[bx + 00h]
	mov	[cf32_gs_32], ax

	pop	ebx
	jmp	short .set_selector_end

.default:
	mov	ax, F386_ds
	mov	[cf32_ds_32], ax
	mov	[cf32_es_32], ax
	mov	[cf32_fs_32], ax
	mov	[cf32_gs_32], ax
.set_selector_end:

	;--------------------------------------------------
	; save to stack
	;--------------------------------------------------
	mov	[si+08h], esp		; save for recovery
	mov	[si+0ch], ss
	mov	word [si+0eh], 0	; *** for Tsugaru bug

	push	dword [si+10h]		; eax
	push	dword [si+14h]		; esi

	;--------------------------------------------------
	; calc stack pointer linear address
	;--------------------------------------------------
	xor	eax, eax
	mov	 ax, ss
	shl	eax, 4
	add	eax, esp
	mov	[cf32_esp], eax		;linear adddress of ss:esp

	;--------------------------------------------------
	; jmp to protect mode
	;--------------------------------------------------
	mov   d [to_PM_EIP], offset .in_32	; jmp to
	mov	esi, [to_PM_data_ladr]
	mov	ax,0de0ch
	int	67h				; VCPI call

;--------------------------------------------------------------------
BITS	32
proc4 .in_32
	lss	esp, cs:[cf32_esp]
	mov	 ds, cs:[cf32_ds_32]
	mov	 es, cs:[cf32_es_32]
	mov	 fs, cs:[cf32_fs_32]
	mov	 gs, cs:[cf32_gs_32]

	pop	esi
	pop	eax
	call	far [cs:cf32_target_eip]
	sub	esp, 14		; V86 caller CS:IP and stack parameter area
	push	eax
	push	esi
	pushfw		; stack 24 byte
	%assign .st_diff	24

	;--------------------------------------------------
	; recovery V86 stack
	;--------------------------------------------------
	push	F386_ds
	pop	ds

	cli
	mov	esi, [sw_stack_bottom]	;esi = current switch stack top
	mov	eax, [esi + 18h]	;ret CS:IP
	mov	[esp +.st_diff -14],eax	;save to V86 stack

	;--------------------------------------------------
	; jmp to V86
	;--------------------------------------------------
	lss	esp, [safe_stack_adr]	;switch stack

	mov	eax,[V86_cs]
	push	dword [esi + 06h]	;** V86 gs
	push	dword [esi + 04h]	;** V86 fs
	push	eax			;** V86 ds
	push	dword [esi + 02h]	;** V86 es

	push	dword [esi + 0ch]	;** V86 ss
	mov	eax,  [esi + 08h]	;original V86 esp
	sub	eax, .st_diff
	push	eax			;** V86 sp
	pushf				;eflags (not use?)
	push	dword [V86_cs]		;** V86 CS
	push	offset .ret_PM		;** V86 IP

	mov	ax,0de0ch		;VCPI function 0ch / to V86 mode
	call 	far [VCPI_entry]	;VCPI far call

;--------------------------------------------------------------------
BITS	16
proc4 .ret_PM
	mov	si, [sw_stack_bottom]	; get current swtich stack top
	; [si]
	;	+00 w ds
	;	+1c w flags
	pop	ax			; ax=flags
	push	bx
	mov	bx, [si + 1ch]		; bx=caller flags
	and	bx, 0f200h		; IF and system flag
	and	ax, 1101_1111_1111b	; other flags
	pop	bx
	push	ax			; save flags

	call	free_sw_stack_16

	mov	ds, [si]
	popf
	pop	esi
	pop	eax
	retf


BITS	32
;******************************************************************************
; DATA
;******************************************************************************
segdata	data class=DATA align=4

tmp_eax		dd	0		;
tmp_ebx		dd	0		;
tmp_ecx		dd	0		;
tmp_esp		dd	0		;
tmp_esp_ss	dd	F386_ds		;

save_eax	dd	0
save_esi	dd	0
save_esp	dd	0
save_ss		dd	0


;------------------------------------------------------------------------------
; call V86 routeine
;------------------------------------------------------------------------------
call_V86_adr	dd	0		; call address // CS:IP

cv86_stack_adr	dd	offset cv86_stack
cv86_stack_ss	dd	F386_ds

	; Protect Mode -> V86 stack // VCPI AX=DE0Ch
		dd	0,0		; safety stack 8 byte
		dd	0,0		; stack for far call
cv86_stack:	
cv86_eip	dd	offset call_V86_clear_stack.in_V86
cv86_cs		dd	0
cv86_eflags	dd	0	; not use?
cv86_esp	dd	0
cv86_ss		dd	0
cv86_es		dd	0
cv86_ds		dd	0
cv86_fs		dd	0
cv86_gs		dd	0

cv86_copy_stack	dd	0	; copy start point
cv86_copy_size	dd	0	; copy bytes

;------------------------------------------------------------------------------
; Real mode interrupt hook routines, for call to 32bit from V86.
;------------------------------------------------------------------------------
V86int_table_adr	dd	0
V86int_table_top	dd	0	; V86int_table_adr +3

;------------------------------------------------------------------------------
; call protect mode routeine from V86
;------------------------------------------------------------------------------
cf32_esp	dd	0		;in 32bit linear address
		dd	DOSMEM_sel	;for lss

cf32_target_eip	dd	0		;call target entry
cf32_target_cs	dd	0		;

cf32_ds_32	dw	0
cf32_es_32	dw	0
cf32_fs_32	dw	0
cf32_gs_32	dw	0

;******************************************************************************
;******************************************************************************
