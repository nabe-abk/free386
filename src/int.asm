;******************************************************************************
;　Free386 Interrupt
;******************************************************************************
;[TAB=8]
;
%include	"macro.inc"
%include	"f386def.inc"

%include	"start.inc"
%include	"free386.inc"

%include	"sub32.inc"
%include	"memory.inc"
%include	"selector.inc"
%include	"call_v86.inc"

;//////////////////////////////////////////////////////////////////////////////
; global data
;//////////////////////////////////////////////////////////////////////////////
global		DOS_int_list
global		int21h_table

;******************************************************************************
seg32	text32 class=CODE align=4 use32
;******************************************************************************
;//////////////////////////////////////////////////////////////////////////////
; Interrupt main
;//////////////////////////////////////////////////////////////////////////////
;------------------------------------------------------------------------------
; Dummy for chain dos handler
;------------------------------------------------------------------------------
;
proc4 PM_int_dummy
	push	ebx
	push	ds

	mov	ds ,[esp+0ch]		;CS
	mov	ebx,[esp+08h]		;EIP
	movzx	ebx,b [ebx-1]		;ebx = int number

	pop	ds
	xchg	[esp], ebx		;stack top is int number
%if INT_HOOK
	call	register_dump_from_int
%endif

	jmp	call_V86_int_iret


;------------------------------------------------------------------------------
; CPU Interrupt / int 00h - 1fh
;------------------------------------------------------------------------------
; *** Interrupt Routine MUST be "4 bytes".
;
%define calc_CPU_int_adr(x,y)	PM_int_00h + x*4 + y*4

proc4 cpu_double_fault
	lss	esp, cs:[VCPI_stack_adr]	; load safety stack pointer
	pushf					; eflags
	push	-1				; cs
	push	-1				; eip
	push	byte 08h			; int number
	jmp	cpu_fault

proc4 cpu_stack_fault
	lss	esp, cs:[VCPI_stack_adr]	; load safety stack pointer
	pushf					; eflags
	push	-1				; cs
	push	-1				; eip
	push	byte 0ch			; int number
	jmp	cpu_fault


proc4 PM_int_00h
	; 00h: Zero Divide Error
	; 01h: Debug Exceptions
	; 02h: NMI
	; 03h: Breakpoint (trap)
	; 04h: INTO Overflow (trap)
	; 05h: Bounds Check Fault
	; 06h: Invalid Opcode Fault
	; 07h: Coprocessor Not Available
%assign int_num 0
%rep	8
	push	byte int_num
	jmp	short cpu_fault
%assign int_num int_num+1
%endrep
	;
	; 08h: Double fault (error_code) [abort]
	;
	jmp	short cpu_double_fault
	nop
	nop
	;
	; 09h: Coprocessor Segment Overrun [abort]
	;
	push	byte 09h
	jmp	short cpu_fault
	;
	; 0Ah: Invalid TSS
	;
	push	byte 0ah
	jmp	short cpu_fault_with_error_code
	;
	; 0Bh: Segment Not Present Fault (error_code)
	;
	push	byte 0bh
	jmp	short cpu_fault_with_error_code
	;
	; 0Ch: Stack Exception Fault  (error_code)
	;
	jmp	short cpu_stack_fault
	nop
	nop
	;
	; 0Dh: General Protection Exception (error_code)
	;
	push	byte 0dh
	jmp	short cpu_fault_with_error_code
	;
	; 0Eh: Page Fault (error_code)
	;
	push	byte 0eh
	jmp	short cpu_fault_with_error_code
	;
	; 0Fh: (Reserved)
	;
	push	byte 0fh
	jmp	short cpu_fault

	;
	; 10h: x87 Floating-Point Error
	;
	push	byte 10h
	jmp	short cpu_fault
	;
	; 11h: Alignment Check (error_code)
	;
	push	byte 11h
	jmp	short cpu_fault_with_error_code
	;
	; 12h: Machine Check
	;
	push	byte 12h
	jmp	short cpu_fault
	;
	; 13h: SIMD Floating-Point Exception
	;
	push	byte 13h
	jmp	short cpu_fault
	;
	; 14h: Virtualization Exception
	;
	push	byte 14h
	jmp	short cpu_fault
	;
	; 15h: Control Protection Exception (error code)
	;
	push	byte 15h
	jmp	short cpu_fault_with_error_code
	;
	; 16h-1Bh: (reserved)
	;
%assign int_num 0
%rep	6
	push	byte int_num
	jmp	short cpu_fault
%assign int_num int_num+1
%endrep
	;
	; 1Ch: Hypervisor Injection Exception
	;
	push	byte 1ch
	jmp	short cpu_fault
	;
	; 1Dh: VMM Communication Exception (error code)
	;
	push	byte 1dh
	jmp	short cpu_fault_with_error_code
	;
	; 1Eh: Security Exception (error code)
	;
	push	byte 1eh
	jmp	short cpu_fault_with_error_code
	;
	; 1Fh: (reserved)
	;
	push	byte 1fh
	;jmp	short cpu_fault

	;	+0ch	eflags
	;	+08h	cs
	;	+04h	eip
	;stack	+00h	int number
proc4 cpu_fault
	push	eax
	mov	eax, [esp+4]		; eax = int number
	mov	dword [esp+4], 0	; error code = 0
	xchg	[esp], eax		; recovery eax

	;
	;	+10h	eflags
	;	+0ch	cs
	;	+08h	eip
	;	+04h	error code
	;stack	+00h	int number
proc4 cpu_fault_with_error_code
	push	ds
	push	F386_ds
	pop	ds
	push	eax

	mov	[dump_orig_esp], esp
	push	ss
	pop	dword [dump_orig_ss]

	;	+18h	eflags
	;	+14h	cs
	;	+10h	eip
	;	+0ch	error code
	;	+08h	int number
	;	+04h	ds
	;stack	+00h	eax
	;
	lss	esp,[PM_stack_adr]	; load safety stack
	lds	eax,[dump_orig_esp]	; ds:eax <- old stack
	;
	; copy stack info
	;
	push	dword [eax +18h]	; eflags
	push	dword [eax +14h]	; cs
	push	dword [eax +10h]	; eip
	push	dword [eax +0ch]	; error code
	push	dword [eax +08h]	; int number
	push	set_dump_head_is_fault	; header handler
	push	dword [eax +04h]	; ds
	push	dword [eax +00h]	; eax

	push	F386_ds
	pop	ds			; recovery ds
	;
	; view register dump
	;
	call	register_dump
	;
	; exit
	;
	mov	al, CPU_Fault
	jmp	exit_32


;------------------------------------------------------------------------------
; Hardware Interrupt / Master
;------------------------------------------------------------------------------
proc4 HW_int_master_table
	push	byte 0
	jmp	short HW_int_master_common
	push	byte 1
	jmp	short HW_int_master_common
	push	byte 2
	jmp	short HW_int_master_common
	push	byte 3
	jmp	short HW_int_master_common
	push	byte 4
	jmp	short HW_int_master_common
	push	byte 5
	jmp	short HW_int_master_common
	push	byte 6
	jmp	short HW_int_master_common
	push	byte 7
	; jmp	short HW_int_master_common

proc4 HW_int_master_common
	;///////////////////////////////////////////////
	; common routine
	;///////////////////////////////////////////////
%ifdef USE_VCPI_8259A_API
	push	eax
	mov	al, [cs:vcpi_8259m]
	add	[esp+4], al
	pop	eax
	jmp	call_V86_HW_int_iret

%elif (HW_INT_MASTER > 1fh)
	add	b [esp], HW_INT_MASTER
	jmp	call_V86_HW_int_iret

%else	;*** CPU 割り込みと被っている ******************
	push	edx
	push	eax

	mov	edx,[esp+8]		; load IRQ number

	mov	al,0bh			; read ISR
	out	I8259A_ISR_M, al	;
	in	al, I8259A_ISR_M	; read DATA
	bt	eax,edx			; ハードウェエ割り込み？
	jnc	.CPU_int		; bit が 0 なら CPU割り込み

	add	edx, HW_INT_MASTER		; edx = INT番号
	mov	eax,[cs:intr_table + edx*8 +4]	; edx = 呼び出し先selector
	test	eax,eax				;0?
	jz	.dos_chain			;if 0 jmp

	;/// 登録してある割り込みを呼び出し ///
	mov	edx,[cs:intr_table + edx*8]	;offset

	mov	[esp+8],eax		;セレクタ
	xchg	[esp+4],edx		;eax 復元 と オフセット記録
	pop	eax
	retf				;割り込みルーチン呼び出し


	align	4
.dos_chain:
	mov	[esp+8],edx		;呼び出しINT番号として記録
	pop	eax
	pop	edx
	jmp	call_V86_HW_int_iret


	align	4
.CPU_int:
	lea	eax, [ calc_CPU_int_adr(HW_INT_MASTER, edx) ]	;CPU例外のアドレス
	mov	[esp+8],eax					;セーブ

	pop	eax
	pop	edx
	ret				;CPU 例外呼び出し
%endif

;------------------------------------------------------------------------------
; Hardware Interrupt / Slave
;------------------------------------------------------------------------------
proc4 HW_int_slave_table
	push	byte 0
	jmp	short HW_int_slave_common
	push	byte 1
	jmp	short HW_int_slave_common
	push	byte 2
	jmp	short HW_int_slave_common
	push	byte 3
	jmp	short HW_int_slave_common
	push	byte 4
	jmp	short HW_int_slave_common
	push	byte 5
	jmp	short HW_int_slave_common
	push	byte 6
	jmp	short HW_int_slave_common
	push	byte 7
	; jmp	short HW_int_slave_common

proc4 HW_int_slave_common
	;///////////////////////////////////////////////
	; common routine
	;///////////////////////////////////////////////
%ifdef USE_VCPI_8259A_API
	push	eax
	mov	al, [cs:vcpi_8259s]
	add	[esp+4], al
	pop	eax
	jmp	call_V86_HW_int_iret

%elif (HW_INT_SLAVE > 1fh)
	add	b [esp], HW_INT_SLAVE
	jmp	call_V86_HW_int_iret

%else	;*** CPU 割り込みと被っている ******************
	push	edx
	push	eax

	mov	edx,[esp+8]		;edx = IRQ番号 - 8

	mov	al,0bh			;ISR 読み出しコマンド
	out	I8259A_ISR_S, al	;8259A に書き込み
	in	al, I8259A_ISR_S	;サービスレジスタ読み出し
	bt	eax,edx			;ハードウェエ割り込み？
	jnc	.CPU_int		;bit が 0 なら CPU割り込み

	add	edx, HW_INT_SLAVE		; edx = INT番号
	mov	eax,[cs:intr_table + edx*8 +4]	; edx = 呼び出し先selector
	test	eax,eax				;0?
	jz	.dos_chain			;if 0 jmp

	;/// 登録してある割り込みを呼び出し ///
	mov	edx,[cs:intr_table + edx*8]	;offset

	mov	[esp+8],eax		;セレクタ
	xchg	[esp+4],edx		;eax 復元 と オフセット記録
	pop	eax
	retf				;割り込みルーチン呼び出し


	align	4
.dos_chain:
	mov	[esp+8],edx		;呼び出しINT番号として記録
	pop	eax
	pop	edx
	jmp	call_V86_HW_int_iret


	align	4
.CPU_int:
	lea	eax, [ calc_CPU_int_adr(HW_INT_SLAVE, edx) ]	;CPU例外のアドレス
	mov	[esp+8],eax					;セーブ

	pop	eax
	pop	edx
	ret				;CPU 例外呼び出し
%endif


;//////////////////////////////////////////////////////////////////////////////
; Services
;//////////////////////////////////////////////////////////////////////////////

%include	"int_dos.asm"		;DOS 割り込み処理
%include	"int_dosx.asm"		;DOS-Extender 割り込み処理
%include	"int_f386.asm"		;Free386 オリジナル API

;//////////////////////////////////////////////////////////////////////////////
; DATA
;//////////////////////////////////////////////////////////////////////////////
segdata	data class=DATA align=4

%include	"int_data.asm"		;割り込みテーブルなど

;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////
