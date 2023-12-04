;
;check XMS
;	This is PDS. use NASM.
;	2001/02/10
;
; nasm -f bin chk_xms.asm -o chk_xms.com
;
;----------------------------------------------------------------------------
;segment	.text align=16 class=CODE use16
;-----------------------------------------------------------------------------
;	times	100h	db 0		;ORG 100h の代わり
	org	100h
start:
	mov	ax,4300h	;AH=43h XMS check
	int	2fh		;
	cmp	al,80h		;XMS install?
	jne	NO_XMS

	mov	ax,4310h		;XMS エントリポイントの取得
	int	2fh			
	mov	[XMS_Entry  ],bx	;OFF
	mov	[XMS_Entry+2],es	;SEG

	mov	dx,XMS_ins
	mov	ah,09h
	int	21h


	xor	ah,ah			;ah = 0
	call	far [XMS_Entry]	;XMS call

	mov	dx,XMS30		;XMS 3.0 文字列
	cmp	ah,3			;XMS 3.0?
	je	str_XMS30		;等しければ jmp

	mov	dx,XMS20		;XMS 2.0 文字列
str_XMS30:
	mov	ah,09h
	int	21h


	mov	ax,4c00h
	int	21h



	align	4
NO_XMS:
	mov	dx,NO_ins
	mov	ah,09h
	int	21h

	mov	ax,4c00h
	int	21h

XMS_ins	db	'XMS installed.',13,10,'$'
XMS20	db	'XMS Version 2.0',13,10,'$'
XMS30	db	'XMS Version 3.0',13,10,'$'

NO_ins	db	'XMS is not install.',13,10,'$'

	align	4
XMS_Entry	dd	0

;-----------------------------------------------------------------------------
