;******************************************************************************
; file search test
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
	; set FF to buffer
	mov	eax, -1
	mov	edi, buffer
	mov	ecx, 256/4
	rep	stosd

	; set DTA
	mov	 ah, 1ah
	mov	edx, buffer	;ds:edx
	int	21h

	; search file
	mov	 ah, 4eh
	xor 	ecx, ecx	;attribute = 0
	mov	edx, file	;file name
	int	21h
	jc	end

.loop:
	mov	edi, buffer + 1eh
	mov	ecx, 20h
	xor	al, al
	repne	scasb
	mov	dword [edi], 24_0A_0Dh	; 13 10 '$'

	mov	ah, 09h
	mov	edx, buffer + 1eh
	int	21h		;print file name

	; search next file
	mov	ah, 4fh
	int	21h
	jnc	.loop

end:
	mov	ah, 4ch
	int	21h


;------------------------------------------------------------------------------
	align	16
;------------------------------------------------------------------------------
file	db	'*.asm',0

	align	16
buffer	resb	64
	db	'$$',0	;safety
