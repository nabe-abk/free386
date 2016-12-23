;------------------------------------------------------------------------------
;COM ﾌｧｲﾙ作成の為のサブルーチン群
;
;	This is PDS.
;	made by nabe@abk  1998/03/31
;------------------------------------------------------------------------------
;NASM 用に移植。
;
;[TAB=8]
;
%include	"nasm_abk.h"		;NASM 用ヘッダファイル

%include	"f386def.inc"
%include	"f386sub.inc"

segment	text align=16 class=CODE use16
;##############################################################################
;●サブルーチン (16 bit)
;##############################################################################
;------------------------------------------------------------------------------
;○パラメーター解析
;------------------------------------------------------------------------------
;
	public	get_parameter

max_paras	equ	20h	;最大パラメーター数

	align	2
get_parameter:
	push	ax
	push	bx
	push	dx
	push	si


	mov	bx,081h	-1	;コマンドラインパラメタ･アドレス -1
	mov 	dl,0		;文字列中かのフラグに使用　最初は off に
				;  1:文字列中  0:文字列中でない
	mov	si,offset paras_p	;各パラメタへのポインタ記録用配列ロード

	align	2
.loop:
	inc	bx		;bx ステップ
	mov	al,[bx]		;パラメタロード

	cmp	al,' '  	;SPACE
	jz	.kugiri		;区切り発見
	cmp	al,'	'	;TAB
	jz	.kugiri		;区切り発見

	cmp	al,0dh		;パメメーター終了コード
	jz	.exit		;パラメーターの終わり(ループ脱出)

	;
	;文字列中
	;
	cmp	dl,0			;文字列中フラグロード
	jne	.loop			; 0でなければ文字列中なのでそのままﾙｰﾌﾟ

	;
	;新規文字列発見
	;
	mov	[si],bx			;パラメタ文字列のポインタ記録
	mov	dl,01			;文字列中 flag-on
	add	si,2			;配列内アドレスステップ
	inc	b [paras]		;現在のパラメータ数 +1
	cmp	b [paras],max_paras	;現在のパラメーター数 と 解析最大値比較
	je	.exit			;解析ループ脱出

	jmp	.loop			;ループ


	align	2
.kugiri:
	mov	byte [bx],0		;null に
	mov 	dl,0			;文字列中かのフラグを off に
	jmp	short .loop		;ループ



	align	2
	;パラメーター１文字解析ループ脱出
.exit:
	mov	byte [bx],00h		;0 に書換え
	mov	[paras_last],bx		;末尾として記録

	pop	si
	pop	dx
	pop	bx
	pop	ax
	ret


;------------------------------------------------------------------------------
;○英小文字→英大文字
;------------------------------------------------------------------------------
;
;	in	ds:bx	…変換する文字列（null で終わる）
;
;
	public	small_to_large

	align	2
small_to_large:
	push	ax
	push	bx
	push	cx

	mov	ch,11000011b		;２バイト文字判別用テーブル
	dec	bx

	align	2
small_to_large_loop:
	inc	bx
	mov	al,[bx]		;一文字ロード

	cmp	al,0		;null と比較
	je	s2l_end		;ルーチン終了


	;
	;小文字の範囲か確認
	;
	cmp	al,'a'			;コード61h と比較
	jb	small_to_large_loop	;それより小さければジャンプ
	cmp	al,'z'			;コード7ah と比較
	ja	s2l_2byte_code_check	;それより大きければジャンプ

	;
	;小文字→大文字変換
	;
	sub	al,'a' - 'A'		;コード上での差 20hを引く
	mov	[bx],al			;変換コードを記録

	jmp	small_to_large_loop	;ループ


	;
	;２バイト文字か確認
	;
	align	2
s2l_2byte_code_check:
	shr	al,4		;４ビット右シフト（÷16）

	;al ビットのテーブルを調べる

	mov	cl,al			;シフトの為に cl に
	mov	ax,1			;ax に 1 を
	shl	ax,cl			;指定ビットまでシフトする
	test	cx,ax			;ビットテーブル内のテスト
	jz	small_to_large_loop	;フラグが立ってなければループ

	;２バイトコードである

	inc	bx			;次のコードを無視する
	jmp	small_to_large_loop	;ループ


	align	2
s2l_end:
	pop	cx
	pop	bx
	pop	ax
	ret



;------------------------------------------------------------------------------
;○英大文字→英小文字
;------------------------------------------------------------------------------
;
;	in	ds:bx	…変換する文字列（null で終わる）
;
;
	public 	large_to_small

	align	2
large_to_small:
	push	ax
	push	bx
	push	cx

	mov	ch,11000011b		;２バイト文字判別用テーブル
	dec	bx

	align	2
large_to_small_loop:
	inc	bx
	mov	al,[bx]		;一文字ロード

	cmp	al,0		;null と比較
	je	s2l_end		;ルーチン終了（小文字→大文字と一緒）


	;
	;小文字の範囲か確認
	;
	cmp	al,'A'			;コード61h と比較
	jb	large_to_small_loop	;それより小さければジャンプ
	cmp	al,'Z'			;コード7ah と比較
	ja	l2s_2byte_code_check	;それより大きければジャンプ

	;
	;小文字→大文字変換
	;
	add	al,'a' - 'A'		;コード上での差 20hを足す
	mov	[bx],al			;変換コードを記録

	jmp	large_to_small_loop	;ループ


	;
	;２バイト文字か確認
	;
	align	2
l2s_2byte_code_check:
	shr	al,4		;４ビット右シフト（÷16）

	;al ビットのテーブルを調べる

	mov	cl,al			;シフトの為に cl に
	mov	ax,1			;ax に 1 を
	shl	ax,cl			;指定ビットまでシフトする
	test	cx,ax			;ビットテーブル内のテスト
	jz	large_to_small_loop	;フラグが立ってなければループ

	;２バイトコードである

	inc	bx			;次のコードを無視する
	jmp	large_to_small_loop	;ループ



;------------------------------------------------------------------------------
;○Ｈｅｘから二進数への変換
;------------------------------------------------------------------------------
;
;	in	ds:di	…解析する文字列（null で終わる）
;	ret	ax	…結果の数値
;		Cy=1	…エラー
;
;
	public	hex_to_bin

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
	public	HEX_conv4
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
	public	HEX_conv2
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
	public	string_print
string_print:
	push	eax
	push	ebx
	push	edx

	mov	ebx,edx		;ebx 文字列先頭
	dec	ebx		;-1 する

	align	4
SP_search_null:
	inc	ebx		;ポインタ更新
	cmp	byte [ebx],0	;NULL 文字と比較
	jne	SP_search_null

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
;	変換するケタ数は ecx 桁（2～10桁 ／ 厳守！！）
;
;ret	edi = 最後の文字の次の byte
;
	public	bin2deg_32
bin2deg_32:
	push	eax
	push	ebx
	push	ecx
	push	edx
	push	esi
	push	ebp

	mov	ebx,offset deg_table	;10^n 数値テーブル
	mov	esi,offset deg_str	;10進 文字列変換テーブル

	dec	ecx			;桁数 -1
	mov	ebp,15			;危険防止のためのマスク値
	mov	b [esi],' '		;0 の部分に スペースを入れる
	and	ecx,ebp			;危険防止のためのマスク

	align	4
b2d32_loop:	;----------------loop---
	xor	edx,edx			;edx = 0
	div	d [ebx + ecx*4]		;最上位のケタから割っていく
					;edx.eax / 10^ecx = eax (余り=edx)
	and	eax,ebp			;危険防止のため（for 最上位桁）

	test	eax,eax			;値チェック
	jz	b2d32_1			;0 だったら jmp
	mov	b [esi],'0'		;0 の位置に '0' を入れる
b2d32_1:

	mov	al,[esi + eax]		;該当文字コード (0～9)
	mov	[edi],al		;記録
	mov	eax,edx			;eax = 余り
	inc	edi			;次の文字格納位置ヘ

	loop	b2d32_loop		;ecx = 0 になるまで繰り返す
	;--------------------loop end---

	mov	b [esi],'0'		;0 の位置に '0' を入れる
	mov	al,[esi + eax]		;最後の桁の文字コード (0～9)
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
;	eax を 16進数 で、[edi] に記録する。
;	変換するケタ数は cl 桁 = 1-8
;
;ret	edi = 最後の文字の次の byte
;
	public	bin2hex_32
bin2hex_32:
	push	eax
	push	ebx
	push	ecx
	push	edx

	mov	edx, edi
	call	eax2hex

	pop	edx
	pop	ecx
	pop	ebx
	pop	eax
	ret


;------------------------------------------------------------------------------
;------------------------------------------------------------------------------


	align	4
;//////////////////////////////////////////////////////////////////////////////
;●データ領域
;//////////////////////////////////////////////////////////////////////////////
segment	data align=16 class=CODE use16
group	comgroup text data
;------------------------------------------------------------------------------
	public	paras,paras_last,paras_p

paras		dw	0,0		;発見したパラメーターの数
paras_last	dw	0,0		;0dh の位置
paras_p		resw	max_paras	;ポインタ配列

	align	4
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

deg_str:
hex_str	db	'0123456789ABCDEF'

;*** 16 進数 数値変換用テーブル ***
h2b	db	 0, 1, 2, 3, 4, 5, 6, 7,  8, 9,-1,-1,-1,-1,-1,-1
	db	-1,10,11,12,13,14,15,-1, -1,-1,-1,-1,-1,-1,-1,-1
	db	-1,-1,-1,-1,-1,-1,-1,-1, -1,-1,-1,-1,-1,-1,-1,-1
	db	-1,10,11,12,13,14,15,-1



cr_lf	db	13,10,'$'


;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
