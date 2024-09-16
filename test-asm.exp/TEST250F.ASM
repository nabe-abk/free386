;******************************************************************************
; int 21 AX=250Fh test
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
	mov	eax, ds
	mov	ebx, 2823h
	mov	ecx, 1800h
	call	test_250fh

	mov	eax, 40h	; all memory selector
	mov	 es, eax
	mov	ebx, 012345h
	mov	ecx, 800h
	call	test_250fh

	mov	ebx, 022333h
	mov	ecx, 0FFF0h
	call	test_250fh

	mov	ebx, 022333h
	mov	ecx, 10000h
	call	test_250fh

	mov	ebx, 0BFF00h
	mov	ecx, 0F0h
	call	test_250fh

	mov	ebx, 0BFF00h
	mov	ecx, 100h
	call	test_250fh

	mov	ebx, 0FFF00h
	mov	ecx, 0ffh
	call	test_250fh

	mov	ebx, 0FFF00h
	mov	ecx, 100h
	call	test_250fh

	mov	ebx, 288000h
	mov	ecx, 100h
	call	test_250fh

	;-----------------------------------------
	; end
	;-----------------------------------------
	mov	ah, 4ch
	int	21h


;------------------------------------------------------------------------------
	align 16
test_250fh:
	mov	eax, es
	call	print_eax_hex
	mov	al, ':'
	int	29h
	mov	eax, ebx
	call	print_eax_hex

	PRINT	size
	mov	eax, ecx
	call	print_eax_hex

	mov	ax, 250fh
	int	21h

	PRINT	ecx_is
	mov	eax, ecx
	call	print_eax_hex

	PRINT	crlf
	ret

;------------------------------------------------------------------------------
	align 16
;------------------------------------------------------------------------------
msg1	db	':$'

size	db	'  size=$'
ecx_is	db	'  ecx=$'
crlf	db	13,10,'$'
error	db	'  error!',13,10,'$'


;------------------------------------------------------------------------------
; number to hex digits
;------------------------------------------------------------------------------
; in	eax = value
;
	align	16
print_eax_hex:
	pusha
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

	popa
	ret

hex_str	db	'0123456789abcdef'
hex	db	'####_####$'

