;
;VSYNC NOP for PC-98
;
; nasm -f bin vsynop98.asm -o vsynop98.com
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
	jmp	short start2

	align	4
handler:
	push	ax

	out	64h,al		;クリアレジスタに適当な値を出力
	mov	al,20h
	out	00h,al		;bit-5 = 1(EOI bit)

	pop	ax
	iret



start2:
	mov	dx, handler
	mov	ah, 25h
	mov	al, 0Ah			; Interrupt number
	int	21h			; Set vector

	mov	bx,[02ch]		; PSP's ENV segment addres
	mov	ah,49h			;
	mov	es,bx			;
	int	21h			; free ENV memory

	mov	dx, start2		; calc handler size
	add	dx, 0fh
	shr	dx, 4

	mov	ah,31h			; TERMINATE and STAY RESIDENT / 常駐終了
	mov	al,0			; RET = 0
	int	21h

