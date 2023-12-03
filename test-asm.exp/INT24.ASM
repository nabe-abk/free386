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
%ifdef	DRIVE_B
	%define	DRIVE_NUM	2
	%define	DRIVE_NAME	'B'
%elifdef DRIVE_C
	%define	DRIVE_NUM	3
	%define	DRIVE_NAME	'C'
%endif
;------------------------------------------------------------------------------
..start:
	PRINT	msg

	mov	ax, 4700h
	mov	esi, buf
	mov	 dl, DRIVE_NUM
	int	21h

	PRINT	msg2

	mov	ah, 4ch
	int	21h

msg	db	'int 24h test. Access to drive ',DRIVE_NAME,':',13,10,'$'
msg2	db	13,10,'Exit program "normally"',13,10,'$'

buf	times 64 db 0

