;
; テスト用 1998/02/22
;	もぉ～やだぁ～
;
;This is 'PDS'
;
;[TAB=8]
	.386p
code	segment	para public 'CODE' use16
	assume	cs:code,ds:code
	org	100h

;------------------------------------------------------------------------------
PRINT	macro	STRING
	mov	dx,offset STRING
	mov	ah,09h
	int	21h
	endm

;------------------------------------------------------------------------------
start:
	PRINT	iopl

	pushf		;フラグプッシュ
	pop	ax	;フラグ取得
	shr	ax,12	;IOPL を下へ
	and	ax,3	;IOPL を AND
	add	ax,'0'	;数値に変換

	mov	dl,al	;出力 DL
	mov	ah,02h	;1 文字出力
	int	29h	;DL を出力

	PRINT	cr_lf

	mov	dx,offset rm
	mov	eax,cr0
	test	ax,1	;PE ビットをテスト
	jz	short check_paging

	mov	dx,offset pm

check_paging:
	mov	ah,09h
	int	21h

	PRINT	paging
	test	eax,80000000h
	mov	dx,offset _on
	jnz	_end

	mov	dx,offset _off

_end:
	mov	ah,09h
	int	21h

	;プロセス終了
	mov	ah,4Ch
	int	21h	;終了

pm	db	'Virtual 86 Mode',13,10,'$'
rm	db	'Real Mode',13,10,'$'

iopl	db	'IOPL = $'
s	db	'0123'
cr_lf	db	13,10,'$'

paging	db	'paging = $'
_on	db	'on ',13,10,'$'
_off	db	'off',13,10,'$'

;------------------------------------------------------------------------------
code	ends
	end	start
