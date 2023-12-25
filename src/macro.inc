;******************************************************************************
; Free386 macro
;******************************************************************************
;
%define	b	byte
%define	w	word
%define	d	dword
%define	offset
%define	byte_x(x)	byte ((x) - 100h)

%macro	proc8	1
	global	%1
%1:
%endmacro
%macro	proc16	1
	global	%1
	align	2
%1:
%endmacro
%macro	proc32	1
	global	%1
	align	4
%1:
%endmacro

%imacro	PRINT16	1
	mov	dx,%1
	mov	ah,09h
	int	21h
%endmacro

%imacro	PRINT32	1
	mov	edx,%1
	mov	ah,09h
	int	21h
%endmacro

;******************************************************************************
; stack macro
;******************************************************************************
%imacro start_sdiff	0
	%assign	.sdiff	0
%endmacro
%imacro end_sdiff	0
	%if .sdiff != 0
		%error Stack error!
	%endif
%endmacro


%imacro push_x	1
	push	%1
	%assign	.sdiff	.sdiff + 4
%endmacro
%imacro pushf_x	0
	pushf
	%assign	.sdiff	.sdiff + 4
%endmacro
%imacro pusha_x	0
	pusha
	%assign	.sdiff	.sdiff + 20h
%endmacro
%imacro pop_x	1
	pop	%1
	%assign	.sdiff	.sdiff - 4
%endmacro
%imacro popf_x	0
	popf
	%assign	.sdiff	.sdiff - 4
%endmacro
%imacro popa_x	0
	popa
	%assign	.sdiff	.sdiff - 20h
%endmacro

;******************************************************************************
;segment for Microsoft LINK.EXE
;******************************************************************************
%ifdef MSLINK

%macro seg16	1
	BITS 16
%endmacro

%macro seg32	1
	BITS 32
%endmacro

%macro segdata	1
	align 4
%endmacro

%macro segheap	1
	align 16
%endmacro

%else

%define seg16	segment
%define seg32	segment
%define segdata	segment
%define segheap	segment

%endif

;******************************************************************************
;Free386 dependent macro
;******************************************************************************
;------------------------------------------------------------------------------
; call XMS Driver
;------------------------------------------------------------------------------
%macro	XMS_function	0
	call	far [XMS_entry]		;XMS far call
%endmacro

;------------------------------------------------------------------------------
; call V86 macro
;------------------------------------------------------------------------------
%define O_CV86_FARCALL	00h	; far call
%define O_CV86_INT	01h	; int flag
%define O_CV86_CLSEG	02h	; clear ds,es

%macro	V86_INT	1
	push	byte %1					;int number
	push	dword (O_CV86_INT | O_CV86_CLSEG)
	call	call_V86_clear_stack
%endmacro

;------------------------------------------------------------------------------
; carry macros
;------------------------------------------------------------------------------
%imacro	set_cy	0		;Carry set
	or	b [esp+8], 01h
%endmacro

%imacro	clear_cy 0		;Carry reset
	and	b [esp+8],0feh
%endmacro

save_cy:	; for typo safety
cy_save:	;
cy_set:		;
cy_clear:	;

%imacro	iret_save_cy	0
	jc	.__set_cy
	clear_cy
	iret
.__set_cy:
	set_cy
	iret
%endmacro

%imacro	iret_set_flags 0
%endmacro




;------------------------------------------------------------------------------
; interrupt label call
;------------------------------------------------------------------------------
%imacro	callint 1
	pushf
	push	cs
	call	%1
%endmacro

;------------------------------------------------------------------------------
; interrupt hook for register dump
;------------------------------------------------------------------------------
%imacro call_RegisterDumpInt	1
%if INT_HOOK
	push	%1
	call	register_dump_from_int
	mov	[esp], eax
	pop	eax
%endif
%endmacro

%imacro call_DumpDsEdx		1
%if INT_HOOK && PRINT_TSUGARU && DUMP_DS_EDX
	push	ecx
	mov	ecx, %1
	call	debug_dump_ds_edx
	pop	ecx
%endif
%endmacro

