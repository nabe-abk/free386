;******************************************************************************
; General protection fault
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
..start:
	PRINT	msg_01
	mov	edx, 0
	mov	eax, [edx]

	PRINT	msg_02
	mov	edx, 0fffffffh
	mov	eax, [edx]

	mov	ah,4ch
	xor	al,al
	int	21h




msg_01	db	'Access to null pointer.',13,10,'$'
msg_02	db	'Access to 0fffffffh pointer.',13,10,'$'

