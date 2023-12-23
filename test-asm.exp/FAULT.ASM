;******************************************************************************
; General protection fault
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
	PRINT	msg_01
	mov	eax, 00000123h
	mov	ebx, 02022222h
	mov	ecx, 03330333h
	mov	edx, 04404444h
	mov	esi, 05555505h
	mov	edi, 06606606h
	mov	ebp, 07777770h
	push	24h
	push	2ch
	push	34h
	pop	gs
	pop	fs
	pop	es
	xor	edx, edx
	mov	eax, [edx]

	PRINT	msg_02
	mov	edx, 0fffffffh
	mov	eax, [edx]

	mov	ah,4ch
	xor	al,al
	int	21h




msg_01	db	'Access to void pointer.',13,10,'$'
msg_02	db	'Access to 0fffffffh pointer.',13,10,'$'

