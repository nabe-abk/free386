;******************************************************************************
;　Free386 original function service
;******************************************************************************
;[TAB=8]

	global	setup_F386_int

;******************************************************************************
;・Free386 オリジナルファンクションのセットアップ
;******************************************************************************
	align	4
setup_F386_int:
	mov	cl,F386_INT			;割り込み番号
	mov	edx,offset Free386_function	;割り込みファンクション

	push	ds
	push	cs
	pop	ds				;ds:edx = エントリポイント
	mov	ax,2504h			;割り込みの設定
	int	21h				;DOS-Extender call

	mov	cl,INT_REGDUMP			;割り込み番号
	mov	edx,offset register_dump_iret	;レジスタdumpサービス
	mov	ax,2504h			;割り込みの設定
	int	21h				;DOS-Extender call

	pop	ds				;ds 復元
	ret


;******************************************************************************
;■Free386 オリジナルファンクション
;******************************************************************************
	align	4
Free386_function:
	push	eax			;

	cmp	ah,F386_INT_fn_MAX	;最大値
	ja	.no_func		;それ以上なら jmp

	movzx	eax,ah				;機能番号
	mov	eax,[cs:F386fn_table + eax*4]	;ジャンプテーブル参照

	xchg	[esp],eax		;eax復元 & ジャンプ先記録
	ret				;テーブルジャンプ

;------------------------------------------------------------------------------
;・未知のファンクション
;------------------------------------------------------------------------------
	align	4
.no_func:		;未知のファンクション
F386fn_unknown:
	set_cy		;Cy =1
	iret


;------------------------------------------------------------------------------
;・未対応ファンクションリスト
;------------------------------------------------------------------------------
	align	4
F386fn_02h:
F386fn_03h:
F386fn_04h:
F386fn_05h:
F386fn_06h:
F386fn_07h:

F386fn_08h:
F386fn_09h:
F386fn_0ah:
F386fn_0bh:
F386fn_0ch:
F386fn_0dh:
F386fn_0eh:
F386fn_0fh:

F386fn_12h:
F386fn_13h:
F386fn_14h:
F386fn_15h:
F386fn_16h:
F386fn_17h:
	set_cy		;Cy =1
	iret


;//////////////////////////////////////////////////////////////////////////////
;●情報取得ファンクション
;//////////////////////////////////////////////////////////////////////////////
;------------------------------------------------------------------------------
;・Free386 バージョン情報の取得 ah=00h
;------------------------------------------------------------------------------
	align	4
F386fn_00h:
	mov	al,Major_ver	;Free386 メジャバージョン
	mov	ah,Minor_ver	;Free386 マイナーバージョン
	mov	ebx,F386_Date	;日付
	mov	ecx,0		;reserved
	mov	edx,' ABK'	;for Free386 check
	iret

;------------------------------------------------------------------------------
;・機種コード取得 ah=01h
;------------------------------------------------------------------------------
	align	4
F386fn_01h:
	mov	eax,MACHINE_CODE	;機種コード
	iret




;//////////////////////////////////////////////////////////////////////////////
;●拡張APIファンクション
;//////////////////////////////////////////////////////////////////////////////
;------------------------------------------------------------------------------
;◇標準API のロード ah=10h
;------------------------------------------------------------------------------
	align	4
F386fn_10h:
	pusha
	push	ds
	push	es

	push	DOSENV_sel
	push	F386_ds
	pop	ds
	pop	es
	xor	esi,esi
	mov	edi,[work_adr]	;ワークアドレス

	align	4
.search:mov	al,[es:esi]	;ロード
	inc	esi		;ポインタ更新
	test	al,al		;値チェック
	jnz	.search
	mov	al,[es:esi]	;ロード
	inc	esi		;ポインタ更新
	test	al,al		;値チェック
	jnz	.search
	
	;es:esi 環境領域の終わり
	add	esi,byte 2	;ファイル名

	align	4
.cpy:	mov	al,[es:esi]	;起動ファイルの絶対PATHコピー
	mov	[edi],al	;
	inc	esi
	inc	edi
	test	al,al
	jnz	.cpy

	;パス部分のみ取り出す
.srch2:	dec	edi
	cmp	b [edi],'\'
	jne	.srch2
	inc	edi

	;ファイル名を連結する
	mov	esi,offset default_API	;標準APIのファイル名
.cpy2:	mov	al,[esi]
	mov	[edi],al
	inc	esi
	inc	edi
	test	al,al
	jnz	.cpy2

	mov	edx,[work_adr]	;ファイル名 (ASCIIz)
	mov	esi,edx		;バッファアドレス
	call	load_exp
	jc	.error

	push	ds
	mov	[_esp],esp	;ss:esp の設定
	mov	[_ss] ,ss	;
	jmp	run_exp		;API 初期設定ルーチンの実行

	align	4
.error:	pop	es
	pop	ds
	popa
	set_cy
	iret


;------------------------------------------------------------------------------
;◇ロードしたAPIからの復帰 ah=11h
;------------------------------------------------------------------------------
	align	4
F386fn_11h:
	cmp	d [cs:_ss],0		;セーブしてあるスタックの値確認
	je	.error

	lss	esp,[cs:stack_pointer]	;スタック復帰
	pop	ds

	mov	d [_ss],0		;ss をクリア
	pop	es
	pop	ds
	popa
	clear_cy
	iret


	align	4
.error:	set_cy				;プログラムロード中でない
	iret

