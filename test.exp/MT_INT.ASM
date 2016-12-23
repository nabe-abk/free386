;******************************************************************************
;　マルチタスク　サポート　ライブラリ
;******************************************************************************
;
;　★割り込み関連ルーチン部門
;
;　　1998/03/19　製作開始
;    1998/03/20  PC98/FM-TOWNS完成
;    1998/04/01  FM-R/TOWNSタイマー作成。
;                割り込みマスク状態を保存するように変更。
;    1998/06/08  PC-9801 の割り込み初期化時、
;                割り込み要因をクリアするようにする。
;    1998/07/20  PC-98 Timer とりあえず作る (made by kattyo)
;    1998/07/26  ↑を組み込み。機種番号指定の変更。
;    1998/08/08  一般プログラム用のインターフェイス追加。
;                上位の割り込みを許可する為 sti をハンドラの先頭に入れた。
;                割り込みハンドラの内部仕様の変更。
;    1998/08/22  割り込み種類の定数変更。もう変えないと思います(^^;
;    2000/03/02  PC-98 MOUSE を作成 (made by kattyo)
;
;		'ABK project' all right reserved. Copyright (C)nabe@abk
;
;[TAB=8]
	.386
code	segment dword public 'CODE' use32
	assume	cs:code,ds:code


;==============================================================================
;■定数宣言
;==============================================================================

;・機種番号定義（mtask.h と同じ）

_PC98_TIMER	equ	10h	;NEC PC9801 ｼﾘｰｽﾞ / EPSON互換機 :TIMER
_PC98_VSYNC	equ	11h	;NEC PC9801 ｼﾘｰｽﾞ / EPSON互換機 :VSYNC
_PC98_MOUSE	equ	14h	;NEC PC9801 ｼﾘｰｽﾞ / EPSON互換機 :MOUSE
_FM_TIMER	equ	20h	;Fujitsu FMR/FM-TOWNS ｼﾘｰｽﾞ / Panacom ｼﾘｰｽﾞ
_FMT_VSYNC	equ	21h	;Fujitsu FM-TOWNS ｼﾘｰｽﾞ         :VSYNC
_PCAT		equ	30h	;IBM PC/AT互換機(通称 DOS/V機)

setVector	equ	2506h	;プロテクトモード割り込みベクタ設定：2504h
				;リアル/プロテクトは、2506h。



	align	4
;------------------------------------------------------------------------------
;●割り込みハンドラの登録
;------------------------------------------------------------------------------
;int	register_handler(int machin,int para,void *handler);
;
;	machin   ＝ 機種番号
;	para     ＝ 各割り込みルーチンへの引数
;	*handler ＝ ユーザー割り込みハンドラへのポインタ
;
	public	register_handler
register_handler proc near
	push	ebp
	mov	ebp,esp
	push	ebx
	push	esi
	push	edi

	cmp	dword ptr [machin],-1	;未使用か？
	jne	short _error_end	;既に使用されている


	mov	edi,setVector	;割り込み発生の条件
				;int 21 による割り込み設定時の機能番号
				;リアル/プロテクトで常にプロテクトの割り込み


	mov	eax,[ebp+10h]			;第３引数（High 関数）
	mov	ebx,offset HighC_handler +4	;ﾊﾝﾄﾞﾗ call のｱﾄﾞﾚｽ
	sub	eax,ebx				;相対アドレス算出
	mov	[HighC_handler],eax		;呼び出しアドレス記録


	mov	[handlerDS],ds			;ハンドラの ds を保存する
	mov	eax,[ebp+08h]			;第１引数（機種番号）
	mov	esi,offset HighC_call_handler	;一次呼び出しハンドラ
	mov	machin,eax			;機種番号保存
	mov	edx,[ebp+0ch]			;第２引数（引数）


	push	offset	Ret_label_rh	;戻りラベル記録

	cmp	al,_PC98_VSYNC
	je	PC98_VSYNC

	cmp	al,_PC98_TIMER
	je	PC98_TIMER

	cmp	al,_PC98_MOUSE
	je	PC98_MOUSE

	cmp	al,_FMT_VSYNC
	je	FMT_VSYNC

	cmp	al,_FM_TIMER
	je	FM_timer

;	cmp	al,_PCAT
;	je	PCAT

	align	4
_error_end:
	add	esp,04		;スタック取り除き
	mov	eax,-1		;戻り値 -1
	pop	edi
	pop	esi
	pop	ebx
	pop	ebp
	ret

	align	4
Ret_label_rh:
	xor	eax,eax		;戻り値 0(正常)
	pop	edi
	pop	esi
	pop	ebx
	pop	ebp
	ret



	align	4
;------------------------------------------------------------------------------
;●割り込みハンドラの登録 for MTASK
;------------------------------------------------------------------------------
;
;	eax ＝ 機種番号
;	edx ＝ 各割り込みルーチンへの引数
;	esi ＝ ユーザー割り込みハンドラへのポインタ
;
	public	register_handler_MTASK
register_handler_MTASK:
	push	ebx
	push	edi

	cmp	dword ptr [machin],-1	;未使用か？
	jne	short _error_end_MTASK	;既に使用されている


	mov	edi,setVector		;割り込み発生の条件
					;int 21 による割り込み設定時の機能番号


	mov	[handlerDS],ds	;ハンドラの ds を保存する
	mov	machin,eax	;機種番号保存

	push	offset	Ret_label_rh_MTASK	;戻りラベル記録

	cmp	al,_PC98_VSYNC
	je	PC98_VSYNC

	cmp	al,_PC98_TIMER
	je	PC98_TIMER

	cmp	al,_PC98_MOUSE
	je	PC98_MOUSE

	cmp	al,_FMT_VSYNC
	je	FMT_VSYNC

	cmp	al,_FM_TIMER
	je	FM_timer

;	cmp	al,_PCAT
;	je	PCAT

	align	4
_error_end_MTASK:
	add	esp,04		;スタック取り除き
	mov	eax,-1		;戻り値 -1
	pop	edi
	pop	ebx
	ret

	align	4
Ret_label_rh_MTASK:
	xor	eax,eax		;戻り値 0(正常)
	pop	edi
	pop	ebx
	ret



;------------------------------------------------------------------------------
;●割り込みハンドラの登録　（PC-9801ｼﾘｰｽﾞ VSYNC 登録）
;------------------------------------------------------------------------------
	align	4
PC98_VSYNC:
	cli			;割り込み禁止

	mov	cl,0ah			;cl <- VSYNC 割り込みを示す割り込み番号
	call	original_vector_save	;現在の割り込みハンドラ保存


;////// 割り込みベクタの登録 //////
	push	ds

	mov	edx,offset PC98_VSYNC_handler
	mov	ax,cs
	mov	ds,ax
	mov	eax,edi				;割り込み登録の機能番号ロード
	int	21h

	pop	ds


;////// ユーザー割り込みハンドラの登録 //////
	mov	eax,esi				;登録するハンドラ
	mov	ebx,offset PC98_handler +4	;ﾊﾝﾄﾞﾗ call のｱﾄﾞﾚｽ
	sub	eax,ebx				;相対アドレス算出
	mov	PC98_handler,eax		;呼び出しアドレス記録


;///// 割り込み要因クリア /////

	out	64h,al		;VSYNC-割り込み要因クリアレジスタ
				;クリアレジスタに適当な値を出力

	;PC-9801 はこれをしてやらないと、
	;割り込みが発生してくれない………
	;TOWNS はそんな事はないのにぃ………

;////// VSYNC割り込みの許可設定 //////
	;
	;操作はマスタ側のみ
	;
	in	al,02h		;割り込みマスクレジスタから読み込み
	mov	Mask_reg_bak,al	;現在値保存
	and	al,11111011b	;VSYNC割り込みマスク（割り込み許可へ）
	out	02h,al		;割り込みマスクレジスタ書き換え

	sti	;割り込み許可
	ret






;------------------------------------------------------------------------------
;●割り込みハンドラの登録　（PC-9801ｼﾘｰｽﾞ TIMER 登録）
;------------------------------------------------------------------------------
	align	4
PC98_TIMER:
	cli			;割り込み禁止

	mov	cl,08h			;cl <- VSYNC 割り込みを示す割り込み番号
	call	original_vector_save	;現在の割り込みハンドラ保存


;////// 割り込みベクタの登録 //////
	push	ds

	mov	edx,offset PC98_TIMER_handler
	mov	ax,cs
	mov	ds,ax
	mov	eax,edi			;割り込み登録の機能番号ロード
	int	21h

	pop	ds


;////// ユーザー割り込みハンドラの登録 //////
	mov	eax,esi				;登録するハンドラ
	mov	ebx,offset PC98T_handler +4	;ﾊﾝﾄﾞﾗ call のｱﾄﾞﾚｽ
	sub	eax,ebx				;相対アドレス算出
	mov	PC98T_handler,eax		;呼び出しアドレス記録


;////// TIMER割り込みの設定 //////
	;
	;操作はマスタ側のみ
	;
	mov	al, 00110100b	;ｶｳﾝﾀ0, ﾊﾞｲﾅﾘｶｳﾝﾄ, ﾓｰﾄﾞ2, LSB,MSBの順に読み書き
	out	077h, al	;モード設定

	mov	al, 07dh	;	割込周期設定
	out	71h, al		;下位	
	mov	al, 099h	;	997Dh = 約 1/60 に１回
	out	71h, al		;上位	

	in	al,02h		;割り込みマスクレジスタから読み込み
	mov	Mask_reg_bak,al	;現在値保存
	and	al,11111110b	;TIMER割り込みマスク（割り込み許可へ）
	out	02h,al		;割り込みマスクレジスタ書き換え

	sti	;割り込み許可
	ret





;------------------------------------------------------------------------------
;●割り込みハンドラの登録　（PC-9801ｼﾘｰｽﾞ MOUSE 登録）
;------------------------------------------------------------------------------
	align	4
PC98_MOUSE:
	cli			;割り込み禁止

	mov	cl,15h			;cl <- マウス割り込みを示す割り込み番号
	call	original_vector_save	;現在の割り込みハンドラ保存


;////// 割り込みベクタの登録 //////
	push	ds

	mov	edx,offset PC98_MOUSE_handler
	mov	ax,cs
	mov	ds,ax
	mov	eax,edi			;割り込み登録の機能番号ロード
	int	21h

	pop	ds


;////// ユーザー割り込みハンドラの登録 //////
	mov	eax,esi				;登録するハンドラ
	mov	ebx,offset PC98M_handler +4	;ﾊﾝﾄﾞﾗ call のｱﾄﾞﾚｽ
	sub	eax,ebx				;相対アドレス算出
	mov	PC98M_handler,eax		;呼び出しアドレス記録


;////// MOUSE割り込みの設定 //////
	;
	;スレーブ
	;
	mov	dx, 0BFDBh
	mov	al, 00000001b	;割込周期 60Hz に
	out	dx, al		;マウスIFモード設定

;	mov	al, ????	;「8255A モード0出力」
;	out	07FDFh, al	;8255A コントロールレジスタ
	mov	dx, 07FDDh
	mov	al, 00000000b	;カウンタラッチせず,X軸下位4bit,割込許可
	out	dx, al		;モード出力
	
;	mov	al, ????	;「8255A モード0入力」に戻す
;	out	07FDFh, al	;8255A コントロールレジスタ

	in	al,0ah		;割り込みマスクレジスタから読み込み
	mov	Mask_reg_bak,al	;現在値保存
	and	al,11011111b	;MOUSE割り込みマスク（割り込み許可へ）
	out	0ah,al		;割り込みマスクレジスタ書き換え

	sti	;割り込み許可
	ret







;------------------------------------------------------------------------------
;●割り込みハンドラの登録　（FM-TOWNSｼﾘｰｽﾞ VSYNC 登録）
;------------------------------------------------------------------------------
	align	4
FMT_VSYNC:

	cli			;割り込み禁止

	mov	cl,4bh			;cl <- VSYNC 割り込みを示す割り込み番号
	call	original_vector_save	;現在の割り込みハンドラ保存


;////// 割り込みベクタの登録 //////

	push	fs
	push	eax
	push	ecx
	push	edx

	mov	eax,50h			;IDT Read/Write セレクタ
	mov	fs,ax
	mov	edx,4bh	*8		;4bh : VSYNC

	mov	ecx,offset FMT_VSYNC_handler
	mov	 ax,cx			;オフセット下位ロード
	shr	ecx,16			;下位にもってく
	mov	fs:[edx],ax		;IDT に記録
	mov	fs:[edx+6],cx		;IDT に記録
	mov	ax,cs
	mov	fs:[edx+2],ax

	pop	edx
	pop	ecx
	pop	eax
	pop	fs



;////// ユーザー割り込みハンドラの登録 //////
	mov	eax,esi				;登録するハンドラ
	mov	ebx,offset FMT_handler +4	;ﾊﾝﾄﾞﾗ call のｱﾄﾞﾚｽ
	sub	eax,ebx				;相対アドレス算出
	mov	FMT_handler,eax			;呼び出しアドレス記録


;////// VSYNC割り込みの許可設定 //////
	in	al,12h		;割り込みマスクレジスタから読み込み
	mov	Mask_reg_bak,al	;現在値保存

	out	6ch,al		;PIC ｱｸｾｽ、1μ秒ウェイトレジスタへ書き込み
	cmc			; ウエイトレジスタがない場合
	cmc			; この３命令でウエイトとする

	and	al,11110111b	;VSYNC割り込みマスク（割り込み許可へ）
	out	12h,al		;割り込みマスクレジスタ書き換え

	sti	;割り込み許可
	ret








;------------------------------------------------------------------------------
;●割り込みハンドラの登録　（FM-R/TOWNSｼﾘｰｽﾞ Panacomｼﾘｰｽﾞ タイマー登録）
;------------------------------------------------------------------------------
	align	4
FM_timer:

	cli			;割り込み禁止

	mov	cl,40h			;cl <- タイマ割り込みを示す割り込み番号
	call	original_vector_save	;現在の割り込みハンドラ保存


;////// 割り込みベクタの登録 //////
	push	ds

	mov	edx,offset FM_timer_handler
	mov	ax,cs
	mov	ds,ax
	mov	eax,edi		;割り込み登録の機能番号ロード
	int	21h

	pop	ds


;////// ユーザー割り込みハンドラの登録 //////
	mov	eax,esi				;登録するハンドラ
	mov	ebx,offset FM_handler +4	;ﾊﾝﾄﾞﾗ call のｱﾄﾞﾚｽ
	sub	eax,ebx				;相対アドレス算出
	mov	FM_handler,eax			;呼び出しアドレス記録


;///// タイマー別割り込みマスク /////

	in	al,60h			;カウンタ割り込みマスク状況ロード
	shr	al,2			;書き込みの為の右シフト
	mov	timer_mask_bak,al	;タイマごとの割り込みマスクバックアップ
	or	al,1			;タイマー#0 のマスク解除
	out	60h,al			;書き込み


;////// タイマー割り込みの許可設定 //////
	in	al,02h		;割り込みマスクレジスタから読み込み
	mov	Mask_reg_bak,al	;現在値保存

	out	6ch,al		;PIC ｱｸｾｽ、1μ秒ウェイトレジスタへ書き込み
	cmc			; ウエイトレジスタがない場合
	cmc			; この３命令でウエイトとする

	and	al,11111110b	;VSYNC割り込みマスク（割り込み許可へ）
	out	02h,al		;割り込みマスクレジスタ書き換え

	sti	;割り込み許可
	ret




;------------------------------------------------------------------------------
;○割り込み登録　オリジナルハンドラの保存
;------------------------------------------------------------------------------
	align	4
original_vector_save:
	mov	Int_number,cl	;登録した割り込み番号を記録

;//// ネイティブ側の現在のハンドラ保存 /////

	push	es

	mov	ax,2502H		;プロクテモードベタク取得
	int	21h			;es:ebx <- int cl
	mov	native_vector_seg,es
	mov	native_vector_off,ebx

	pop	es

;///// リアル側の現在のハンドラ保存 /////

	mov	ax,2503h		;リアルモードのベクタ取得
	int	21h			;ebx <- リアルベクタ
	mov	real_vector,ebx

	ret


register_handler endp









	align	4
;------------------------------------------------------------------------------
;●割り込みハンドラから呼ばれる、High-C 関数呼び出しルーチン
;------------------------------------------------------------------------------
HighC_call_handler proc near
;	push	eax
	push	ecx
	push	edx
	push	es
	push	fs
	push	gs

	mov	es,cs:[handlerDS]	;ハンドラ ds を es にもロード

	;call	user_hander		;ハンドラーコール
		db	0e8h		;マシン語表記
HighC_handler	dd	$+4		;登録した High-C 関数のアドレス

	pop	gs
	pop	fs
	pop	es
	pop	edx
	pop	ecx
;	pop	eax
;	ret

	pop	eax
	pop	ds
	iretd


HighC_call_handler endp





	align	4
;------------------------------------------------------------------------------
;●割り込みハンドラ　PC-9801 V-SYNC
;------------------------------------------------------------------------------
PC98_VSYNC_handler:
	sti		;自分より上位の割り込みを許可

	push	ds
	push	eax


;///// 割り込み要因クリア /////

	out	64h,al		;VSYNC-割り込み要因クリアレジスタ
				;クリアレジスタに適当な値を出力

;///// End Of Interrupt 発行 /////

	mov	al,20h	;bit-5 = 1(EOI bit)
	out	00h,al	;マスタ側へ


;///// ユーザーハンドラコール /////

	mov	ds,cs:[handlerDS]	;ハンドラ ds をロード

	;jmp	user_hander		;ハンドラーコール
		db	0e9h		;マシン語表記
PC98_handler	dd	$+4		;登録したハンドラへのオフセット

	pop	eax	;dummy
	pop	ds
	iretd



	align	4
;------------------------------------------------------------------------------
;●割り込みハンドラ　PC-9801 TIMER
;------------------------------------------------------------------------------
PC98_TIMER_handler:
	push	ds
	push	eax


;///// End Of Interrupt 発行 /////

	mov	al,20h	;bit-5 = 1(EOI bit)
	out	00h,al	;マスタ側へ


;///// ユーザーハンドラコール /////

	mov	ds,cs:[handlerDS]	;ハンドラ ds をロード

	;jmp	user_hander		;ハンドラーコール
		db	0e9h		;マシン語表記
PC98T_handler	dd	$+4		;登録したハンドラへのオフセット


	pop	eax	;dummy
	pop	ds
	iretd



	align	4
;------------------------------------------------------------------------------
;●割り込みハンドラ　PC-9801 MOUSE
;------------------------------------------------------------------------------
PC98_MOUSE_handler:
	push	ds
	push	eax


;///// End Of Interrupt 発行 /////

	;スレーブ

	cli
	mov	al,20h		;SLAVE へ EOI 出力
	out	0008h,al
	
	jmp	$+2		;WAIT
	mov	al,0Bh		;ISR read mode set(slave)
	out	0008h,al
	
	jmp	$+2		;I/O WAIT
	in	al,0008h	;ISR read(slave)
	cmp	al,00h		;スレーブの他の割込はすべて終了している？
	jne	PC98_MOUSE_handler_EoiEnd
	
	mov	al,20h		;スレーブの割込が全て終了している時は
	out	0000h,al	;マスタへも EOI 発行
PC98_MOUSE_handler_EoiEnd:
	sti


;///// ユーザーハンドラコール /////

	mov	ds,cs:[handlerDS]	;ハンドラ ds をロード

	;jmp	user_hander		;ハンドラーコール
		db	0e9h		;マシン語表記
PC98M_handler	dd	$+4		;登録したハンドラへのオフセット


	pop	eax	;dummy
	pop	ds
	iretd


	align	4
;------------------------------------------------------------------------------
;●割り込みハンドラ　FM-TOWNS V-SYNC
;------------------------------------------------------------------------------

FMT_VSYNC_handler:
	push	ds
	push	eax

	push	es
	push	ebx

	push	60h
	pop	es
	mov	ebx,0c807eh
	inc	byte ptr es:[ebx]

	pop	ebx
	pop	es


;///// 割り込み要因クリア /////
	push	edx

	mov	dx,5cah		;VSYNC-割り込み要因クリアレジスタ
	out	dx,al		;クリアレジスタに適当な値を出力

	pop	edx


;///// End Of Interrupt 発行 /////

	mov	al,20h	;bit-5 = 1(EOI bit)
	out	10h,al	;スレーブ側へ

	out	6ch,al	;PIC ｱｸｾｽ、1μ秒ウェイトレジスタへ書き込み
	cmc		; ウエイトレジスタがない場合
	cmc		; この３命令でウエイトとする

	;マスタ側
	out	00h,al	;bit-5 = 1(EOI bit)

	sti		;割り込み許可


;///// ユーザーハンドラコール /////

	mov	ds,cs:[handlerDS]	;ハンドラ ds をロード

	;jmp	user_handler		;ハンドラーコール
		db	0e9h		;マシン語表記
FMT_handler	dd	$+4		;登録したハンドラへのオフセット


	pop	eax	;dummy
	pop	ds
	iretd




	align	4
;------------------------------------------------------------------------------
;●割り込みハンドラ　FM-R/Panacom/TOWNS タイマー
;------------------------------------------------------------------------------

FM_timer_handler:
	push	ds
	push	eax


;///// 割り込み要因クリア /////

	in	al,60h		;割り込み許可情報ロード
	shr	al,2		;書き込みの為の 2ﾋﾞｯﾄ右ｼﾌﾄ
	or	al,80h		;割り込み要因クリア(タイマ#0)
	out	60h,al		;書き込み


;///// End Of Interrupt 発行 /////

	;マスタ側
	mov	al,20h	;bit-5 = 1(EOI bit)
	out	00h,al


;///// ユーザーハンドラコール /////

	mov	ds,cs:[handlerDS]	;ハンドラ ds をロード

	;jmp	user_handler		;ハンドラーコール
		db	0e9h		;マシン語表記
FM_handler	dd	$+4		;登録したハンドラへのオフセット


	pop	eax	;dummy
	pop	ds
	iretd














	align	4
;------------------------------------------------------------------------------
;●割り込み解除
;------------------------------------------------------------------------------
	public	free_handler
free_handler proc near

	mov	cl,Int_number		;登録した割り込み番号ロード
	cli				;割り込み禁止

;//// 旧割り込みベクタの復元 /////

	push	ds
	push	ebx

	mov	ebx,real_vector		;リアルモードの旧割り込みベクタロード
	mov	edx,native_vector_off	;プロテクトモードの
	mov	ds ,native_vector_seg	;　旧割り込みベクタロード

	mov	ax,2507H		;プロクテト/リアル ベタク設定
	int	21h			;Dos-Extenderコール

	pop	ebx
	pop	ds


;//// 機種別の PIC 8259A の再設定 /////

	mov	eax,machin		;機種番号ロード
	mov	dword ptr [machin],-1	;解放した事を記憶

	cmp	al,_PC98_VSYNC
	je	free_PC98_VSYNC

	cmp	al,_PC98_TIMER
	je	free_PC98_TIMER

	cmp	al,_FMT_VSYNC
	je	free_FMT_VSYNC

	cmp	al,_FM_TIMER
	je	free_FM_timer

;	cmp	al,_PCAT
;	je	free_PCAT

	ret


	align	4
;------------------------------------------------------------------------------
;●割り込み解除　PC-9801 V-SYNC解除
;------------------------------------------------------------------------------
free_PC98_VSYNC:
	;//////////
	; マスタ側
	;//////////
	in	al,02h		;割り込みマスクレジスタから読み込み

	mov	cl,Mask_reg_bak	;変更前の値ロード
	and	al,11111011b	;変更したビット
	and	cl,00000100b	;    のみ元に戻す
	or	al,cl		;VSYNC 割り込み許可フラグを元に戻す

	out	02h,al		;割り込みマスクレジスタ書き換え

	sti
	ret



;------------------------------------------------------------------------------
;●割り込み解除　PC-9801 TIMER解除
;------------------------------------------------------------------------------
free_PC98_TIMER:
	;//////////
	;マスタ側
	;//////////
	in	al,02h		;割り込みマスクレジスタから読み込み

	mov	cl,Mask_reg_bak	;変更前の値ロード
	and	al,11111110b	;変更したビット
	and	cl,00000001b	;    のみ元に戻す
	or	al,cl		;TIMER 割り込み許可フラグを元に戻す

	out	02h,al		;割り込みマスクレジスタ書き換え

	sti
	ret



;------------------------------------------------------------------------------
;●割り込み解除　PC-9801 マウス解除
;------------------------------------------------------------------------------
free_PC98_MOUSE:
	
	;//////////////
	;マウス割込解除
	;//////////////
	
;	mov	al, ????	;「8255A モード0出力」
;	out	07FDFh, al	;8255A コントロールレジスタ
	mov	dx, 07FDDh
	mov	al, 00010000b	;カウンタラッチせず,X軸下位4bit,割込禁止
	out	dx, al		;モード出力
	
;	mov	al, ????	;「8255A モード0入力」に戻す
;	out	07FDFh, al	;8255A コントロールレジスタ
	
	;//////////
	;スレーブ側
	;//////////
	in	al,0ah		;割り込みマスクレジスタから読み込み

	mov	cl,Mask_reg_bak	;変更前の値ロード
	and	al,11011111b	;変更したビット
	and	cl,00100000b	;    のみ元に戻す
	or	al,cl		;TIMER 割り込み許可フラグを元に戻す

	out	0ah,al		;割り込みマスクレジスタ書き換え

	sti
	ret



	align	4
;------------------------------------------------------------------------------
;●割り込み解除　FM-TOWNS V-SYNC
;------------------------------------------------------------------------------
free_FMT_VSYNC:
	;//////////
	;スレーブ側
	;//////////
	in	al,12h		;割り込みマスクレジスタから読み込み

	mov	cl,Mask_reg_bak	;変更前の値ロード
	and	al,11110111b	;変更したビット
	and	cl,00001000b	;    のみ元に戻す
	or	al,cl		;VSYNC 割り込み許可フラグを元に戻す

	out	12h,al		;割り込みマスクレジスタ書き換え

	sti
	ret



	align	4
;------------------------------------------------------------------------------
;●割り込み解除　FM-R/Panacom/TOWNS タイマー
;------------------------------------------------------------------------------
free_FM_timer:

	;
	;タイマごとの割り込みマスク情報復元
	;
	in	al,60h			;タイマー別のマスク情報ロード
	shr	al,2			;書き込み用に2bit 右シフト
	mov	cl,timer_mask_bak	;変更前の値ロード
	and	al,11111110b		;変更したビット
	and	cl,00000001b		;　　のみ元に戻す
	or	al,cl			;変更前に戻す
	out	60h,al			;書き込み


	;//////////
	; マスタ側
	;//////////
	in	al,02h		;割り込みマスクレジスタから読み込み

	mov	cl,Mask_reg_bak	;変更前の値ロード
	and	al,11111110b	;変更したビット
	and	cl,00000001b	;    のみ元に戻す
	or	al,cl		;タイマー割り込み許可フラグを元に戻す

	out	02h,al		;割り込みマスクレジスタ書き換え

	sti
	ret


free_handler endp




;==============================================================================
;■データ領域
;==============================================================================

Int_number		db	?	;割り込み番号
Mask_reg_bak		db	?	;割り込み許可/禁止情報保存
timer_mask_bak		db	?	;タイマごとの割り込みマスクバックアップ

	align	4
machin			dd	-1	;機種番号保存変数
handlerDS		dw	?	;ＤＳの値を保存する

native_vector_seg	dw	?	;(seg)元のプロテトモード
native_vector_off	dd	?	;(off)  ﾍﾞｸﾀ保存変数
real_vector		dd	?	;[seg(H):off(L)]ﾘｱﾙﾓｰﾄﾞﾍﾞｸﾀ保存変数


;------------------------------------------------------------------------------
code	ends
	end
