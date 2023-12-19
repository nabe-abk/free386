;------------------------------------------------------------------------------
;COM file subroutine
;------------------------------------------------------------------------------
;[TAB=8]
;
%include	"macro.inc"
%include	"f386def.inc"
;******************************************************************************
segment	text class=CODE align=4 use16
;##############################################################################
; 16bit subroutine
;##############################################################################
;------------------------------------------------------------------------------
; parse parameter
;------------------------------------------------------------------------------
; in	si = string pointer
;	bp = string pointer max
; out	si = found parameter pointer
;	cx = length of parameter
;
proc16 get_next_parameter
	push	ax
	push	bx
	xor	cx, cx

.loop:
	mov	bx, si
	add	bx, cx
	cmp	bx, bp
	ja	.last

	mov	al,[bx]
	cmp	al,' '  	;SPACE
	jz	.separator
	cmp	al,'	'	;TAB
	jz	.separator
	cmp	al,20h		;NULL or CR
	jb	.last

	inc	cx
	jmp	short .loop

.separator:
	test	cx,cx
	jnz	.last
	inc	si
	jmp	short .loop

.last:
	pop	bx
	pop	ax
	ret

;------------------------------------------------------------------------------
;○Ｈｅｘから二進数への変換
;------------------------------------------------------------------------------
;
;	in	ds:di	…解析する文字列（null で終わる）
;	ret	ax	…結果の数値
;		Cy=1	…エラー
;
;
	global	hex_to_bin

	align	2
hex_to_bin:
	push	bx
	push	si
	push	di

	xor	ax,ax
	xor	bx,bx
	mov	si,offset h2b	;数値変換テーブルロード

	align	2
hex_to_bin_loop:
	mov	bl,[di]
	inc	di

	cmp	bl,0		;null と比較
	je	h2b_end		;ルーチン終了

	;
	;『h』は無視する
	;
	cmp	bl,'H'
	je	hex_to_bin_loop
	cmp	bl,'h'
	je	hex_to_bin_loop

	cmp	bl,'0'		;コード30h と比較
	jb	h2b_error	;それより小さければエラー(=jmp)
	cmp	bl,'f'		;コード66h と比較
	ja	h2b_error	;それより大きければエラー(=jmp)

	;
	;テーブル検索
	;
	sub	bl,30h		;30h を引く（テーブル検索用）
	mov	bl,[bx+si]	;テーブルの値をロード
	cmp	bl,0ffh		;-1 と比較
	je	h2b_error	;等しいとエラー

	;
	;数値加算
	;
	shl	ax,4		;結果ﾚｼﾞｽﾀ 4 ﾋﾞｯﾄｼﾌﾄ（×4）
	add	ax,bx		;テーブルの値を足す

	jmp	hex_to_bin_loop	;ループ


	align	2
h2b_error:
	pop	di
	pop	si
	pop	bx
	stc		;キャリーセット(エラー)
	ret


	align	2
h2b_end:
	pop	di
	pop	si
	pop	bx
	clc		;キャリークリア(正常終了)
	ret



	align	2
;------------------------------------------------------------------------------
;○数値→Ｈｅｘ変換（４ケタ固定）
;------------------------------------------------------------------------------
;
;	dx を16進数で、[si] に記録する
;	si は ret 時 +4される。
;
	global	HEX_conv4
HEX_conv4:
	push	ax
	push	bx
	push	dx
	push	di
	mov	di,offset hex_str	;16進数文字列
	xor	bx,bx

	;１文字目記録
	mov	bl,dh
	and	bl,0f0h
	shr	bx,4
	mov	al,[di+bx]
	mov	[si],al
	inc	si

	;２文字目記録
	mov	bl,dh
	and	bl,0fh
	mov	al,[di+bx]
	mov	[si],al
	inc	si

	;３文字目記録
bin2Hex_2:			;２文字のみ変換時に使用（笑）
	mov	bl,dl
	and	bl,0f0h
	shr	bx,4
	mov	al,[di+bx]
	mov	[si],al
	inc	si

	;４文字目記録
	mov	bl,dl
	and	bl,0fh
	mov	al,[di+bx]
	mov	[si],al
	inc	si

	pop	di
	pop	dx
	pop	bx
	pop	ax
	ret



	align	2
;------------------------------------------------------------------------------
;○数値→Ｈｅｘ変換（２ケタ固定）
;------------------------------------------------------------------------------
;
;	dl を16進数で、[si] に記録する
;	si は ret 時 +4される。
;
	global	HEX_conv2
HEX_conv2:
	push	ax
	push	bx
	push	dx
	push	di
	mov	di,offset hex_str	;16進数文字列
	xor	bx,bx

	jmp	short	bin2Hex_2	;そんだけかい


;##############################################################################
;●サブルーチン (32 bit)
;##############################################################################
BITS	32
	align	4
;------------------------------------------------------------------------------
;○NULL で終わる文字列の表示
;------------------------------------------------------------------------------
;	ds:[edx]  strings (Null determinant)
;
	global	string_print
string_print:
	push	eax
	push	ebx
	push	edx

	mov	ebx,edx		;ebx 文字列先頭
	dec	ebx		;-1 する

	align	4
.loop:
	inc	ebx		;ポインタ更新
	cmp	byte [ebx],0	;NULL 文字と比較
	jne	short .loop

	mov	byte [ebx],'$'	;文字列終端を一時的に置き換える
	mov	ah,09h		;display string
	int	21h		;DOS call
	mov	byte [ebx],0	;NULL に復元

	mov	ah,09h
	mov	edx,offset cr_lf	;改行
	int	21h			;表示

	pop	edx
	pop	ebx
	pop	eax
	ret


	align	4
;------------------------------------------------------------------------------
;○数値→１０進数変換（ｎケタ）
;------------------------------------------------------------------------------
;
;	eax を 10進数 で、[edi] に記録する。
;	変換するケタ数は ecx 桁（2〜10桁 ／ 厳守！！）
;
;ret	edi = 最後の文字の次の byte
;
	global	bin2deg_32
bin2deg_32:
	push	eax
	push	ebx
	push	ecx
	push	edx
	push	esi
	push	ebp

	mov	ebx,offset deg_table	;10^n 数値テーブル
	mov	esi,offset hex_str	;10進 文字列変換テーブル

	dec	ecx			;桁数 -1
	mov	ebp,15			;危険防止のためのマスク値
	mov	byte [esi],' '		;0 の部分に スペースを入れる
	and	ecx,ebp			;危険防止のためのマスク

	align	4
.loop:
	;----------------loop---
	xor	edx,edx			;edx = 0
	div	dword [ebx + ecx*4]	;最上位のケタから割っていく
					;edx.eax / 10^ecx = eax (余り=edx)
	and	eax,ebp			;危険防止のため（for 最上位桁）

	test	eax,eax			;値チェック
	jz	short .skip		;0 だったら jmp
	mov	byte [esi],'0'		;0 の位置に '0' を入れる
.skip:

	mov	al,[esi + eax]		;該当文字コード (0〜9)
	mov	[edi],al		;記録
	mov	eax,edx			;eax = 余り
	inc	edi			;次の文字格納位置ヘ

	loop	.loop			;ecx = 0 になるまで繰り返す
	;--------------------loop end---

	mov	b [esi],'0'		;0 の位置に '0' を入れる
	mov	al,[esi + eax]		;最後の桁の文字コード (0〜9)
	mov	[edi],al
	inc	edi

	pop	ebp
	pop	esi
	pop	edx
	pop	ecx
	pop	ebx
	pop	eax
	ret


	align	4
;------------------------------------------------------------------------------
;○数値→１６進数変換（ｎケタ）
;------------------------------------------------------------------------------
;
;	eax = value
;	ecx = number of digits
;
;ret	edi = 最後の文字の次の byte
;
	global	bin2hex_32
bin2hex_32:
	push	eax
	push	ebx
	push	ecx
	push	edx

	push	ecx
	mov	edx,ecx
	shl	edx,2		; *4
	mov	cl, 32
	sub	cl, dl
	shl	eax,cl
	pop	ecx

.loop:
	rol	eax, 4
	movzx	ebx, al
	and	bl, 0fh
	mov	dl, [hex_str + ebx]

	cmp	b [edi], '_'
	jne	.skip
	inc	edi
.skip:
	mov	[edi], dl
	inc	edi
	loop	.loop

	pop	edx
	pop	ecx
	pop	ebx
	pop	eax
	ret

;------------------------------------------------------------------------------
;○次の # を書き換える
;------------------------------------------------------------------------------
;	eax	value
;	edi	target
;
	align	4
	global	rewrite_next_hash_to_hex
rewrite_next_hash_to_hex:
	push	ecx
.loop:
	inc	edi
	cmp	b [edi], '#'
	jne	.loop
	call	count_num_of_hash
	call	bin2hex_32
	pop	ecx
	ret


	align	4
	global	rewrite_next_hash_to_deg
rewrite_next_hash_to_deg:
	push	ecx
.loop:
	inc	edi
	cmp	b [edi], '#'
	jne	.loop
	call	count_num_of_hash
	call	bin2deg_32
	pop	ecx
	ret

	align	4
count_num_of_hash:
	push	edi
	xor	ecx, ecx
	jmp	.loop
.skip:
	inc	edi
.loop:
	cmp	b [edi+ecx], '_'
	je	.skip
	cmp	b [edi+ecx], '#'
	jne	.exit
	inc	ecx
	jmp	.loop
.exit:
	pop	edi
	ret

;------------------------------------------------------------------------------
;------------------------------------------------------------------------------


	align	4
;//////////////////////////////////////////////////////////////////////////////
; DATA
;//////////////////////////////////////////////////////////////////////////////
segment	data class=DATA align=4

global	hex_str
;------------------------------------------------------------------------------
deg_table:
deg_00	dd	1
deg_01	dd	10
deg_02	dd	100
deg_03	dd	1000
deg_04	dd	10000
deg_05	dd	100000
deg_06	dd	1000000
deg_07	dd	10000000
deg_08	dd	100000000
deg_09	dd	1000000000

hex_str	db	'0123456789abcdef'

;*** 16 進数 数値変換用テーブル ***
h2b	db	 0, 1, 2, 3, 4, 5, 6, 7,  8, 9,-1,-1,-1,-1,-1,-1
	db	-1,10,11,12,13,14,15,-1, -1,-1,-1,-1,-1,-1,-1,-1
	db	-1,-1,-1,-1,-1,-1,-1,-1, -1,-1,-1,-1,-1,-1,-1,-1
	db	-1,10,11,12,13,14,15,-1

cr_lf	db	13,10,'$'


;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
