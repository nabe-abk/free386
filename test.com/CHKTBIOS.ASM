;
;READ T-BIOS / This is PSD.
;
;	Thanks to Mamiya (san).
;
; nasm -f bin chktbios.asm -o chktbios.com
;
;------------------------------------------------------------------------------
%macro	PRINT	1
	mov	edx,%1
	mov	ah,09h
	int	21h
%endmacro

;------------------------------------------------------------------------------
	org	100h
start:
	mov	dx,3b90h
	call	TOWNS_CMOS_READ
	mov	eax, ebx
	call	eax2hex

	PRINT	msg_address
	PRINT	msg_hex


	mov	dx,3b98h
	call	TOWNS_CMOS_READ
	mov	eax, ebx
	call	eax2hex

	PRINT	msg_limit
	PRINT	msg_hex


	mov	ah,4ch
	xor	al,al
	int	21h

;==============================================================================
;read CMOS
;==============================================================================
	align	4
TOWNS_CMOS_READ:
	add	edx,byte 6	;+3 byte の位置
	in	al,dx		;(C-MOS は偶数番地に張りつけてある)
	mov	bh,al
	sub	edx,byte 2

	in	al,dx		;+2 byte の位置
	mov	bl,al
	sub	edx,byte 2

	shl	ebx,16

	in	al,dx		;+1 byte の位置
	mov	bh,al
	sub	edx,byte 2

	in	al,dx		;+0 byte / 指定番地
	mov	bl,al
	ret


;==============================================================================
;eax to hex
;==============================================================================
	align	4
eax2hex:
	push	bx
	push	cx
	push	di

	mov	di, msg_hex
	mov	cx, 8
.loop:
	rol	eax, 4
	mov	bl, al
	and	bx, 000fh
	mov	dl, [hex_table+bx]

	cmp	byte [di], '_'
	jne	.skip
	inc	di
.skip:
	mov	[di], dl
	inc	di

	dec	cx
	jnz	.loop

	rol	eax, 4
	pop	di
	pop	cx
	pop	bx
	ret

;==============================================================================

msg_hex		db	'0000_0000',13,10,'$'
msg_address	db	'TBIOS OFFSET = ','$'
msg_limit	db	'TBIOS SIZE   = ','$'

	align 4
hex_table	db	'0123456789ABCEDF'

