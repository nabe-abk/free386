;------------------------------------------------------------------------------
;COM file subroutine
;------------------------------------------------------------------------------
;[TAB=8]
;
%include	"macro.inc"
%include	"f386def.inc"
;******************************************************************************
seg16	text class=CODE align=4 use16
;##############################################################################
; 16bit subroutine
;##############################################################################
;------------------------------------------------------------------------------
; parse parameter
;------------------------------------------------------------------------------
; in	si = string pointer
;	bp = length
; out	si = found parameter pointer
;	cx = length of parameter
;	bp = remain length
;
proc2 get_next_parameter
	push	ax
	xor	bx, bx
.loop:
	test	bp, bp
	jz	.last

	mov	al,[si + bx]
	cmp	al,' '  	;SPACE
	jz	.separator
	cmp	al,'	'	;TAB
	jz	.separator
	cmp	al,20h		;NULL or CR
	jb	.last

	inc	bx
	dec	bp
	jmp	short .loop

.separator:
	test	bx,bx
	jnz	.last
	inc	si
	dec	bp
	jmp	short .loop

.last:
	pop	ax
	ret


;------------------------------------------------------------------------------
; parse decimal string
;------------------------------------------------------------------------------
; in	si  = decimal string
; ret	eax = number
;	si  = end of decimal address + 1
;
proc2 parse_decimal_string
	push	ebx
	push	ecx
	push	edx
	push	si

	xor	eax, eax
	xor	ebx, ebx
	mov	ecx, 10
.loop:
	mov	bl, [si]
	inc	si
	sub	bl, '0'
	cmp	bl, 9
	ja	.exit

	mul	ecx		;edx:eax = eax*10
	add	eax, ebx	;add number
	jmp	.loop

.exit:
	pop	si
	pop	edx
	pop	ecx
	pop	ebx
	ret


;------------------------------------------------------------------------------
; number to hex digits
;------------------------------------------------------------------------------
; in	eax = value
;	 di = store string
;
; ret	 di = last store address +1
;
proc2 bin2hex4_16
	push	bx
	push	cx
	push	dx

	mov	cx, 4
.loop:
	rol	ax, 4
	movzx	bx, al
	and	bl, 0fh
	mov	dl, [hex_str + bx]

	mov	[di], dl
	inc	di
	loop	.loop

	pop	dx
	pop	cx
	pop	bx
	ret


;##############################################################################
; 32bit subroutine
;##############################################################################
BITS	32
;------------------------------------------------------------------------------
; output null terminate string
;------------------------------------------------------------------------------
;	ds:[edx]  strings (Null determinant)
;
proc4 print_string_32
	push	eax
	push	ebx
	push	edx

	mov	ebx,edx		; ebx = string point
	xor	al, al		; al = 0
	dec	ebx
.loop:
	inc	ebx
	cmp	byte [ebx], al	; ==0
	jne	short .loop

	mov	byte [ebx],'$'
	mov	ah,09h
	int	21h
	mov	byte [ebx],0

	mov	ah,09h
	mov	edx,offset cr_lf
	int	21h

	pop	edx
	pop	ebx
	pop	eax
	ret


;------------------------------------------------------------------------------
; binary to decimal number
;------------------------------------------------------------------------------
; in	eax = number
;	edi = store buffer
;	ecx = number of digits
; ret	edi = last store address +1
;
proc4 bin2dec_32
	push	eax
	push	ebx
	push	ecx
	push	edx
	push	esi
	push	ebp

	test	ecx, ecx		; safety check
	jz	.exit

	mov	esi, eax		; esi = number

	mov	eax,   1
	mov	ebx,  10
	and	ecx, byte 0fh		; safety
	mov	ebp, ecx		; backup loop counter
.mul:
	push	eax
	mul	ebx			; edx:eax = eax*ebp
	loop	.mul

	mov	edx, esi		; edx = number
	mov	esi, offset hex_str	; hex table

	mov	byte [esi], ' '		; 0 to space
	mov	ecx, ebp		; ecx = num of digits -1
.loop:
	mov	eax, edx		; eax = current number
	xor	edx, edx		; edx = 0
	pop	ebp
	div	ebp			; edx:eax / 10^ecx = eax mod edx

	cmp	ecx, byte 1		; last digit
	je	short .store0		; store '0' to table
	test	eax, eax
	jz	short .skip
.store0:
	mov	byte [esi], '0'		; if non zero, set '0'
.skip:
	and	eax, byte 0fh		; safety
	mov	al,[esi + eax]		; al = char
	mov	[edi],al		; save

	inc	edi
	loop	.loop

.exit:
	pop	ebp
	pop	esi
	pop	edx
	pop	ecx
	pop	ebx
	pop	eax
	ret


;------------------------------------------------------------------------------
; number to hex digits
;------------------------------------------------------------------------------
; in	eax = value
;	ecx = number of digits
;	edi = store string
;
; ret	edi = last store address +1
;
proc4 bin2hex_32
	push	ebx
	push	ecx
	push	edx

	push	ecx
	mov	edx,ecx
	shl	edx,2		; *4
	mov	cl, 32
	sub	cl, dl
	rol	eax,cl
	pop	ecx

.loop:
	rol	eax, 4
	movzx	ebx, al
	and	bl, 0fh
	mov	dl, [hex_str + ebx]

	cmp	b [edi], '_'
	jne	.skip
	inc	edi
.skip:
	mov	[edi], dl
	inc	edi
	loop	.loop

	pop	edx
	pop	ecx
	pop	ebx
	ret

;------------------------------------------------------------------------------
; auto rewrite #### to digits
;------------------------------------------------------------------------------
; in	eax	value
;	edi	target
;
proc4 rewrite_next_hash_to_hex
	push	ecx
	call	count_num_of_next_hash
	call	bin2hex_32
	pop	ecx
	ret

proc4 rewrite_next_hash_to_dec
	push	ecx
	call	count_num_of_next_hash
	call	bin2dec_32
	pop	ecx
	ret

proc4 count_num_of_next_hash
.search_loop:
	inc	edi
	cmp	b [edi], '#'
	jne	.search_loop

	push	edi
	xor	ecx, ecx
	jmp	.count_loop
.skip:
	inc	edi
.count_loop:
	cmp	b [edi+ecx], '_'
	je	.skip
	cmp	b [edi+ecx], '#'
	jne	.exit
	inc	ecx
	jmp	.count_loop
.exit:
	pop	edi
	ret

;##############################################################################
; DATA
;##############################################################################
segdata	data class=DATA align=4

global	hex_str
global	cr_lf

hex_str	db	'0123456789abcdef'
cr_lf	db	13,10,'$'

;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
