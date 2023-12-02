;
;VSYNC ON
;
; nasm -f bin vsync_fm.asm -o vsync_fm.com
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
	PRINT	msg

	in	al,12h
	and	al,11110111b
	out	12h,al

	mov	ah,4ch
	xor	al,al
	int	21h

msg	db	'FM TOWNS Hardware interrupt VSYNC to ON',13,10,'$'
