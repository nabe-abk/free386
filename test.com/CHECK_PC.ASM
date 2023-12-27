;
;PC type check for make.bat
;
; nasm -f bin check_pc.asm -o check_pc.com
;
;[TAB=8]
;------------------------------------------------------------------------------
%macro	PRINT	1
	mov	edx,%1
	mov	ah,09h
	int	21h
%endmacro
;------------------------------------------------------------------------------
	org	100h
start:
	;------------------------------------------------------------
	; check argument
	;------------------------------------------------------------
	mov	si, 80h
	movzx	cx, byte [si]
	test	cx, cx
	jz	.no_argument
	inc	si
.loop:
	lodsb	; al = [si++]
	cmp	al, 20h
	ja	exists_argument
	loop	.loop
.no_argument:

	;------------------------------------------------------------
	; check machine
	;------------------------------------------------------------
	call	check_TOWNS
	jc	.not_TOWNS
	PRINT	is_towns
	mov	al,1
	jmp	short exit

.not_TOWNS:
	call	check_PC98
	jc	.not_PC98
	PRINT	is_pc98
	mov	al,2
	jmp	short exit
	
.not_PC98:
	call	check_AT
	jc	.not_AT
	PRINT	is_at
	mov	al,3
	jmp	short exit

.not_AT:
	;------------------------------------------------------------
	; unknown
	;------------------------------------------------------------
	PRINT	is_unknown
	mov	al, 4
	jmp	short exit

exists_argument:		; errorlevel = 0
	PRINT	exists_arg
	xor	al,al
exit:
	mov	ah,4ch
	int	21h


;------------------------------------------------------------------------------
; msg
;------------------------------------------------------------------------------
exists_arg	db	'Ret=0: exists argument',13,10,'$'
is_towns	db	'Ret=1: FM TOWNS',13,10,'$'
is_pc98		db	'Ret=2: PC-9801/9821',13,10,'$'
is_at		db	'Ret=3: PC/AT compatible',13,10,'$'
is_unknown	db	'Ret=4: Unknown',13,10,'$'


;------------------------------------------------------------------------------
; check routine
;------------------------------------------------------------------------------
	align	2
check_TOWNS:
	in	al,30h		;CPU register
	test	al,al
	jz	.not_fm		;0 is not FM
	inc	al		;
	jz	.not_fm		;0ffh is not FM

	mov	dx,020eh	;Drive switch register
	in	al,dx		;
	and	al,0feh		;
	jnz	.not_TOWNS	;all 0 is TOWNS
	clc
	ret
.not_fm:
.not_TOWNS:
	stc
	ret


	align	2
check_PC98:
	xor	bx,bx
	mov	cx,6
	; Do not use multiples of 4.
	; "multiple of 4" is result 0 on timer#01/02
.loop:
	in	al,71h		;timer #00
	xor	bl,al		;xor
	in	al,73h		;timer #01
	xor	bh,al		;xor
	loop	.loop

 	test	bx,bx
 	jz	.not_pc98
 	clc
 	ret
.not_pc98:
	stc
	ret

	align	2
check_AT:
	xor	bx,bx
	mov	cx,16
.loop:
	in	al,40h		;timer #00
	xor	bl,al		;xor
	in	al,41h		;timer #01
	xor	bh,al		;xor
	loop	.loop

 	test	bx,bx
 	jz	.not_AT
	clc
	ret
.not_AT:
	stc
	ret


