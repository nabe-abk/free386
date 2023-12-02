;
;VSYNC NOP for FM TOWNS
;
; nasm -f bin vsynopfm.asm -o vsynopfm.com
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
	push	dx
	push	ax

	mov	dx,5cah		;VSYNC-割り込み要因クリアレジスタ
	out	dx,al		;クリアレジスタに適当な値を出力

	mov	al,20h		;bit-5 = 1(EOI bit)
	out	10h,al		;スレーブ側へ

	out	6ch,al		;PIC ｱｸｾｽ、1μ秒ウェイトレジスタへ書き込み
	cmc			; ウエイトレジスタがない場合
	cmc			; この３命令でウエイトとする

	;マスタ側
	out	00h,al		;bit-5 = 1(EOI bit)

	pop	ax
	pop	dx
	iret


start2:
	mov	dx, handler
	mov	ah, 25h
	mov	al, 4bh			; Interrupt number
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

