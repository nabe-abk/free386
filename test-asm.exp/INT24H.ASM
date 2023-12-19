;******************************************************************************
; int 24 test
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
main:
	xor	eax, eax
	mov	 al, 24h	; PSP
	mov	 fs, ax

	mov	 al, [fs:81h]	; Argument first byte
	cmp	 al, 'A'
	jb	do_test
	cmp	 al, 'Z'
	ja	.skip1

	; al is 'A'-'Z'
	mov	[drive], al

.skip1:
	cmp	 al, 'a'
	jb	do_test
	cmp	 al, 'z'
	ja	do_test

	; al is 'a'-'z'
	sub	al, 0x20	; to Upper case
	mov	[drive], al

do_test:
	PRINT	msg

	mov	ax, 4700h
	mov	esi, buf
	mov	 dl, [drive]
	sub	 dl, 'A' -1 	; A to 1, B to 2, ....
	int	21h

	PRINT	msg2

	mov	ah, 4ch
	int	21h

msg	db	'int 24h test. Access to drive ',
drive	db	'B',':',13,10,'$'
msg2	db	13,10,'Exit program "normally"',13,10,'$'

buf	times 64 db 0

