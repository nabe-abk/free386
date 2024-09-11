;******************************************************************************
; int 21 AX=2510h and AX=250ch test
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
	mov	ax, 2510h	; Get real mode far call routein
	mov	ecx, 100000h
	int	21h		; will fail

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

	mov	ax, 250dh
	int	21h		; Get real mode link infomation
	call	dump

	mov	[test32_cs], cs
	mov	[proc_off], eax
	mov	[cbuf_off], ebx
	mov	esi, 11223344h
	mov	es:[edx], esi	; save to call buffer

	mov	esi, 55555555h
	mov	edi, 66666666h
	mov	ebp, 77777777h
	mov	ax, 2510h		; Get real mode far call routein
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

	align	4
call_parameter:
	dw	1230h
	dw	5670h
	dw	9ab0h
	dw	7770h
	dd	1111_0011h	; eax
	dd	2222_2222h	; ebx
	dd	3333_7788h	; ecx
	dd	4444_4444h	; edx

v86_adr		dw	test_v86_routine
v86_seg		dw	0

;------------------------------------------------------------------------------
; 32bit routine.
;------------------------------------------------------------------------------
	align	100h
test_32_routine:
	mov	eax, [esp+12]
	mov	ebx, [esp+8]
	int	0ffh
	retf

	align	16
proc_off	dw	0
proc_seg	dw	0
cbuf_off	dw	0
cbuf_seg	dw	0
test32_cs	dw	0

test32_seg_parameter:
test32_gs	dw	20h
test32_fs	dw	60h
test32_es	dw	40h
test32_ds	dw	10h

;------------------------------------------------------------------------------
; 16bit routine.
;------------------------------------------------------------------------------
BITS	16
	align	80h
test_v86_routine:
	push	eax
	push	ebx

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

	mov	gs, cs:[cbuf_seg]
	mov	di, cs:[cbuf_off]
	mov	esi, gs:[di]		; load from callbuffer

	push	dword 0aabbccddh
	push	dword 0eeeeffffh
	push	 word cs
	push	 word test32_seg_parameter
	push	 word cs:[test32_cs]
	push	dword test_32_routine

	call	far [cs:proc_off]
	add	sp, 12h

	mov	eax, 1000
	add	eax, 0ffffffffh

	pop	ebx
	pop	ebx
	stc
	std
	sti
	retf


