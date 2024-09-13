;******************************************************************************
; selector operations test
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
	mov	ah, 48h
	int	21h
	mov	[sel1], eax
	mov	edx, msg1
	call	print_hex

	mov	ah, 48h
	int	21h
	mov	[sel2], eax
	mov	edx, msg1
	call	print_hex

	mov	ah, 48h
	int	21h
	mov	[sel3], eax
	mov	edx, msg1
	call	print_hex

	mov	ah, 48h
	int	21h
	mov	[sel4], eax
	mov	edx, msg1
	call	print_hex


	; delete selector
	push	es
	mov	ah, 49h
	mov	es, [sel2]
	int	21h
	pop	es

	mov	eax, [sel2]
	mov	edx, msg2
	call	print_hex


	xor	eax, eax
	push	es
	mov	es, eax
	mov	ah, 49h
	int	21h
	pop	es

	xor	eax, eax
	mov	edx, msg2
	call	print_hex



	mov	ah, 4ch
	int	21h


sel1	dd	0
sel2	dd	0
sel3	dd	0
sel4	dd	0

msg1	db	'Create selector: ','$'
msg2	db	'Delete selector: ','$'


;------------------------------------------------------------------------------
; number to hex digits
;------------------------------------------------------------------------------
; in	eax = value
;	edx = msg string
;
	align	16
print_hex:
	push	ebx
	push	ecx
	push	edx
	push	edi

	push	eax
	mov	ah, 09h
	int	21h
	pop	eax

	mov	ecx, 8
	mov	edi, hex
.loop:
	rol	eax, 4
	movzx	ebx, al
	and	bl, 0fh
	mov	dl, [hex_str + ebx]

	cmp	byte [edi], '_'
	jne	.skip
	inc	edi
.skip:
	mov	[edi], dl
	inc	edi
	loop	.loop

	PRINT	hex

	pop	edi
	pop	edx
	pop	ecx
	pop	ebx
	ret

hex_str	db	'0123456789abcdef'
hex	db	'####_####',13,10,'$'

