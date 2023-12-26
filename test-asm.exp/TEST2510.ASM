;******************************************************************************
; int 21 4Ah test
;******************************************************************************
;
;[TAB=8]
;------------------------------------------------------------------------------
%macro	PRINT	1
	mov	edx,%1
	mov	ah,09h
	int	21h
%endmacro
;------------------------------------------------------------------------------
segment	text align=4 class=CODE use32
;------------------------------------------------------------------------------
..start:
	mov	ah ,30h
	mov	ebx,'F386'
	int	21h
	cmp	edx,' ABK'
	je	is_f386

	mov	byte [dump], (0c3h - 100h)	; set dump first opcode c3=ret
is_f386:
	mov	ax, 2510h
	mov	ecx, 100000h
	int	21h		; fail test
	call	dump

	mov	ax, 2508h
	mov	bx, cs
	int	21h		; ecx = Get Linear address

	mov	ax, 2509h
	mov	ebx, ecx
	add	ebx, ..start
	int	21h		; ecx = Get physical address
	cmp	ecx, 100000h
	jb	.skip

	PRINT	not1MB
	jmp	exit

.skip:
	sub	ecx, ..start
	shr	ecx, 4
	mov	[v86_seg], cx

	mov	esi, 55555555h
	mov	edi, 66666666h
	mov	ebp, 77777777h
	mov	ax, 2510h
	mov	edx, call_parameter
	mov	ecx, 3
	mov	ebx, [v86_adr]		; call target
	push	088776655h
	push	044332211h
	int	21h

	call	dump
exit:
	mov	ah,4ch
	xor	al,al
	int	21h


	align	4
dump:
	int	0ffh		; free386's dump service
	ret

;------------------------------------------------------------------------------
; DATA
;------------------------------------------------------------------------------
not1MB		db	'Not 1MB address.',13,10,'$'

call_parameter:
	dw	1230h
	dw	5670h
	dw	9ab0h
	dw	7770h
	dd	1111_1010h	; eax
	dd	2222_2222h	; ebx
	dd	3333_7788h	; ecx
	dd	4444_4444h	; edx

v86_adr		dw	test_v86_routine
v86_seg		dw	0

;------------------------------------------------------------------------------
; 16bit routine. seg:2100h
;------------------------------------------------------------------------------

BITS	16
	align	100h
test_v86_routine:
	push	eax
	push	ebx
	push	ecx
	push	edx
	push	esi
	push	edi
	push	ebp

	push	ds
	push	es
	push	fs
	push	gs

	mov	ax, 1
	mov	bx, sp
	add	ss:[bx],   ax
	add	ss:[bx+2], ax
	add	ss:[bx+4], ax
	add	ss:[bx+6], ax
	pop	gs
	pop	fs
	pop	es
	pop	ds

	mov	eax, 1
	add	eax, 0ffffffffh

	pop	eax
	pop	ebp
	pop	edi
	pop	esi
	pop	edx
	pop	ecx
	pop	ebx
	stc
	std
	sti
	retf


