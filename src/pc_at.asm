;******************************************************************************
;Å@Free386	PC/AT dependent code
;******************************************************************************
;
seg16	text class=CODE align=4 use16
;==============================================================================
; check maachine type is PC/AT
;==============================================================================
;Ret	Cy=0	true
;	Cy=1	false
;
; in al,0D0h - TOWNS is 0ffh, PC-98 is 0ffh
; in al,0DAh - TOWNS is 0ffh, PC-98 is 0ffh
;
proc2 check_AT_16
	in	al,0D0h		;DMA Status Register
	add	al, 1		;cy = al is 0ffh
	jc	.ret

	in	al,0DAh		;DMS I/O
	add	al, 1		;cy = al is 0ffh
.ret:	ret

;==============================================================================
; init PC/AT in 16bit mode
;==============================================================================
proc2 init_AT_16
	ret


BITS	32
;==============================================================================
; initalize for PC/AT
;==============================================================================
proc4 init_AT_32
	call	init_VESA
	;
	; run after init_VESA
	;
	mov	ebx,offset AT_memory_map
	call	map_memory
	jnc	.success

	mov	ah, 17		; not enough page table memory
	jmp	error_exit_32

.success:
	mov	esi,offset AT_selector_alias	; make aliases
	call	make_aliases			;
	ret


;------------------------------------------------------------------------------
; initalize VESA 2.0
;------------------------------------------------------------------------------
proc4 init_VESA
	mov	 ax, 4f00h	;install VESA?
	mov	edi,[work_adr]	;buffer
	V86_INT	10h		;VGA/VESA BIOS call
	cmp	ax, 004fh	;support?
	jne	.not_found

	;---------------------------------------------------
	; Found VESA
	;---------------------------------------------------
	cmp	b [verbose], 0
	jz	.skip_msg

	mov	al, [edi+5]
	add	al, '0'
	mov	[msg_found_ver], al
	PRINT32	msg_found
.skip_msg:

	;---------------------------------------------------
	; get video mode list
	;---------------------------------------------------
	;mov	edi,[work_adr]	;buffer
	xor	ebp, ebp	;VRAM max
	mov	cx,  100h

.get_modes:
	mov	ax, 4f01h
	V86_INT	10h		;VESA call
	cmp	ax, 004fh
	jne	.invalid_mode
	;
	; valid mode
	;
	movzx	eax,w [edi + 10h]	; 1 line VRAM size
	movzx	ebx,w [edi + 14h]	; y size
	mul	dword ebx		; edx:eax = Total VRAM size

	cmp	ebp, eax
	ja	.skip
	mov	ebp, eax		; save maximum VRAM size

.skip:
.invalid_mode:
	inc	cx
	cmp	cx, 200h
	jb	.get_modes

	;---------------------------------------------------
	; save and create VRAM selector
	;---------------------------------------------------
	mov	esi, [edi + 28h]	;VRAM phisical address
	mov	eax, 100_0000h		;16MB
	cmp	ebp, eax		;compare 16MB
	jbe	.skip2
	mov	ebp, eax		;max 16MB
.skip2:
	cmp	b [verbose], 0
	jz	.skip_msg2

	push	edi
	mov	edx, msg_vram
	mov	edi, edx
	mov	eax, ebp
	shr	eax, 10			;eax = VRAM size [KB]
	call	rewrite_next_hash_to_dec
	mov	ah, 09h
	int	21h	; PRINT
	pop	edi

.skip_msg2:
	;---------------------------------------------------
	; make selector
	;---------------------------------------------------
	shr	ebp, 12			;size [Byte] to [page]

	; IN	esi = linear address   (4KB Unit)
	;	edx = phisical address (4KB Unit)
	;	ecx = pages
	mov	edx, esi
	mov	ecx, ebp
	call	set_physical_memory

	;mov	edi, [work_adr]
	mov	eax, VESA_VRAM_sel	;selector
	mov	d [edi  ], esi		;base phisical address
	mov	d [edi+4], ebp		;limit
	mov	d [edi+8], 0200h	;R/W / level=0
	call	make_selector_4k

.error:
.not_found:
	ret


BITS	32
;==============================================================================
; exit process for PC/AT in 32bit
;==============================================================================
proc4 exit_AT_32
	ret


BITS	16
;==============================================================================
; exit process for PC/AT in 16bit
;==============================================================================
proc2 exit_AT_16
	ret


;******************************************************************************
; DATA
;******************************************************************************
segdata	data class=DATA align=4

	align	4
AT_memory_map:
		;sel,  base     ,     pages, type/level
	dd	100h, 0ffff0000h,      64/4, 0a00h	 ;R/X boot-ROM
	dd	168h,    0a0000h,      64/4, 0200h	 ;R/W for VGA
	dd	170h,    0b0000h,      64/4, 0200h	 ;R/W for VGA
	dd	178h,    0b8000h,      32/4, 0200h	 ;R/W for VGA
	dd	0	;end of data

	align	4
AT_selector_alias:
			;ORG , alias, type/level
	dd	         100h,  108h,  0000h	;boot-ROM
	dd	VESA_VRAM_sel,  128h,  0200h	;VRAM alias
	dd	VESA_VRAM_sel,  104h,  0200h	;VRAM alias
	dd	VESA_VRAM_sel,  10ch,  0200h	;VRAM alias
	dd	0			;end of data


msg_found	db 'Found VESA Version = '
msg_found_ver	db '0.0',13,10,'$'
msg_vram	db 'VRAM: ##### KB',13,10,'$'

