;******************************************************************************
; Free386 chcker
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
	PRINT	msg

	mov	ebx, msg2
int29test:
	mov	al, [ebx]
	cmp	al, '$'
	je	.exit
	int	29h

	inc	ebx
	jmp	short int29test
.exit:

	; key input
	mov	ah,08h
	int	21h

	; end
	mov	ah,4ch
	xor	al,al
	int	21h


msg	db	'This is test program',13,10,'$'
msg2	db	'<<push any to exit>>',13,10,'$'


