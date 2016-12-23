;
;VSYNC NOP for FM-TOWNS
;
; Original Copyright 1998 by kattyo.
; reversion 0.01 nabe@abk
;
; This is PSD.
;
;====================================== ;マクロ

setvect	macro	intnum		;ベクタアドレス設定 < DS:DX
	mov	ah,25h
	mov	al,intnum
	int	21h
endm

;======================================

code	segment
;====================================== ;割り込みコード
	assume	cs:code,ds:code

	org	100h

start:
	jmp	pro

	align	4
handler:
	push	dx
	push	ax

	mov	dx,5cah		;VSYNC-割り込み要因クリアレジスタ
	out	dx,al		;クリアレジスタに適当な値を出力

	mov	al,20h	;bit-5 = 1(EOI bit)
	out	10h,al	;スレーブ側へ

	out	6ch,al	;PIC ｱｸｾｽ、1μ秒ウェイトレジスタへ書き込み
	cmc		; ウエイトレジスタがない場合
	cmc		; この３命令でウエイトとする

	;マスタ側
	out	00h,al	;bit-5 = 1(EOI bit)


;;	mov	dx,5ech
;;	mov	al,0
;;	out	dx,al

	pop	ax
	pop	dx
	iret





pro:
	mov	ax,cs
	mov	ds,ax

	mov	dx,offset handler
	setvect	04bh			;ベクタ設定

	mov	bx,ds:[02ch]		;PSP より 環境 segment addres 取得 > BX
	mov	ah,49h			;
	mov	es,bx			;
	int	21h			;環境エリア開放


	mov	ah,31h			;常駐終了
	mov	al,0			;RET = 0
	mov	dx,20h			;DX -> パラグラフサイズ
	int	21h

code	ends
	end	start
