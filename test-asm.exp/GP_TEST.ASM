;******************************************************************************
; int 21 / GP_BUFFER test
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
	mov	ah, 38h
	mov	al, 00h
	mov	dx, buf
	int	21h

	; file create
	mov	ah, 3ch
	mov	al, 0001_0010b
	xor	ecx, ecx
	mov	edx, file0
	int	21h

	mov	ebx, eax		; bx = file handle

	; file close
	mov	ah, 3eh
	int	21h

	; rename file
	mov	edx, file0
	mov	edi, file1
	mov	ah, 56h
	int	21h

	; rename file
	mov	edx, file1
	mov	eax, 24h	; PSP
	mov	 es, ax
	mov	edi, 80h	; DTA
	mov	dword es:[edi  ], '1234'
	mov	dword es:[edi+4], '567'
	mov	ah, 56h
	int	21h

	mov	ah, 4ch
	int	21h


;------------------------------------------------------------------------------
	align	16
;------------------------------------------------------------------------------
buf  times 64	db 0ffh

file0		db '__test__',0
file1		db '..\test.obj',0



