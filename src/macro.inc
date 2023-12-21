;******************************************************************************
; Free386 macro
;******************************************************************************
;
%define	b	byte
%define	w	word
%define	d	dword
%define	offset

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

%imacro	PRINT86	1
	mov	dx,%1
	mov	ah,09h
	int	21h
%endmacro

%imacro	PRINT	1
	mov	edx,%1
	mov	ah,09h
	int	21h
%endmacro

%imacro	PRINT_	1
	push	eax
	push	edx
	mov	edx,%1
	mov	ah,09h
	int	21h
	pop	edx
	pop	eax
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
; V86 int macro
;------------------------------------------------------------------------------
%macro	V86_INT	1
	pushf
	push	cs
	push	d (offset .ret_label)
	push	d %1			;int number
	jmp	call_V86_int

	align	4
.ret_label:
%endmacro

%macro	V86_INT_21h	0
	pushf
	push	cs
	call	call_V86_int21
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

;------------------------------------------------------------------------------
; interrupt label call
;------------------------------------------------------------------------------
%imacro	calli	1
	pushf
	push	cs
	call	%1
%endmacro

;------------------------------------------------------------------------------
; interrupt hook for register dump
;------------------------------------------------------------------------------
%imacro call_RegisterDumpInt	1
%if INT_HOOK
	push	d %1
	call	register_dump_from_int
	mov	[esp], eax
	pop	eax
%endif
%endmacro

