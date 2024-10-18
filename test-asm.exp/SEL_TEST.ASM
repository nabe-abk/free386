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
	; delete selector
	mov	eax, 24h
	mov	es, eax
	call	delete_selector

	; delete selector
	xor	eax, eax
	mov	es, eax
	call	delete_selector

	; create selector
	mov	ebx, 110h
	call	create_selector
	mov	[sel1], eax

	; resize_selector
	mov	eax, ds
	mov	 es, eax
	mov	ebx, 1000h
	call	resize_selector

	; create selector
	mov	ebx, 120h
	call	create_selector
	mov	[sel2], eax

	; create selector
	mov	ebx, 0
	call	create_selector
	mov	[sel3], eax

	; set phisical memory
	mov	es, [sel3]
	mov	ecx, 80h	; 512KB
	mov	ebx, 100000h	; address: 1MB-
	call	mapping_phisical_memory

	; set phisical memory
	mov	ecx, 80h	; 512KB
	mov	ebx, 210000h	; address: 2MB-
	call	mapping_phisical_memory

	; create selector
	mov	ebx, 100h
	call	create_selector
	mov	[sel4], eax
	mov	es, eax		; delete
	call	delete_selector

	; delete selector
	mov	es, [sel2]
	call	delete_selector

	; create selector
	mov	ebx, 1000h
	call	create_selector
	mov	[sel2], eax

	; resize_selector
	mov	 es, [sel1]
	mov	ebx, 200h
	call	resize_selector

	; resize_selector
	mov	 es, [sel3]
	mov	ebx, 200h
	call	resize_selector

	; delete selector
	mov	es, [sel3]
	call	delete_selector

	; delete selector
	mov	es, [sel1]
	call	delete_selector

	; resize_selector
	mov	eax, cs
	mov	 es, eax
	mov	ebx, 48h
	call	resize_selector

	; create selector
	mov	ebx, 1000h
	call	create_selector
	mov	[sel2], eax

	;-----------------------------------------
	; end
	;-----------------------------------------
	mov	ah, 4ch
	int	21h


;------------------------------------------------------------------------------
	align	16
;------------------------------------------------------------------------------
sel1	dd	0
sel2	dd	0
sel3	dd	0
sel4	dd	0

msg1	db	'Create  selector: $'
msg2	db	'Delete  selector: $'
msg3	db	'Resize  selector: $'
msg4	db	'mapping selector: $'
size	db	'  size: $'
free	db	'  free memory: $'
err	db	'  error!',13,10,'$'
crlf	db	13,10,'$'


;------------------------------------------------------------------------------
; create selector
;------------------------------------------------------------------------------
	align	16
create_selector:
	PRINT	msg1

	mov	ah, 48h
	int	21h
	jc	.error

	call	print_eax_hex

	push	eax
	PRINT	size
	mov	eax, ebx
	shl	eax, 12
	call	print_eax_hex
	pop	eax

	call	print_free_memory
	ret

.error:
	PRINT	err
	ret

;------------------------------------------------------------------------------
; delete selector
;------------------------------------------------------------------------------
	align	16
delete_selector:
	PRINT	msg2

	mov	eax, es
	lsl	ebx, eax
	inc	ebx

	call	print_eax_hex

	mov	ah, 49h
	int	21h
	jc	.error

	PRINT	size
	mov	eax, ebx
	call	print_eax_hex

	call	print_free_memory
	ret

.error:
	PRINT	err
	ret

;------------------------------------------------------------------------------
; resize selector
;------------------------------------------------------------------------------
	align	16
resize_selector:
	PRINT	msg3

	mov	eax, es
	call	print_eax_hex

	mov	ah, 4ah
	int	21h
	jc	.error

	PRINT	size
	mov	eax, es
	lsl	eax, eax
	inc	eax
	call	print_eax_hex

	call	print_free_memory
	ret

.error:
	PRINT	err
	ret


;------------------------------------------------------------------------------
; mapping phisical memory
;------------------------------------------------------------------------------
	align	16
mapping_phisical_memory:
	PRINT	msg4

	mov	eax, es

	call	print_eax_hex
	PRINT	size
	mov	eax, es
	lsl	eax, eax
	inc	eax
	call	print_eax_hex

	mov	ax, 250ah	; in es, ebx, ecx
	int	21h
	jc	.error

	call	print_free_memory
	ret

.error:
	PRINT	err
	ret



;------------------------------------------------------------------------------
; print max allocate memory
;------------------------------------------------------------------------------
	align	16
print_free_memory:
	push	eax
	PRINT	free

	mov	ah, 48h
	mov	ebx, -1
	int	21h

	mov	eax, ebx
	shl	eax, 12
	call	print_eax_hex

	PRINT	crlf

	pop	eax
	ret

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

