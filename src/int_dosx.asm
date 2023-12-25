;******************************************************************************
;　Free386	割り込み処理ルーチン / DOS-Extender サービス
;******************************************************************************
;[TAB=8]
;
;==============================================================================
;★DOS-Extender仕様 DOS fuction (int 21)
;==============================================================================
;------------------------------------------------------------------------------
;・Verison 情報取得  AH=30h
;------------------------------------------------------------------------------
proc32 int_21h_30h
	clear_cy	; stack eflags clear

	;eax の上位16bit に 'DX' を入れる
	and	eax,0ffffh	;下位16bit 取り出し
	shl	eax,16		;一度上位へずらす
	mov	 ax,4458h	;'DX' : Dos-Extender
	rol	eax,16		;上位ビットと下位ビットを入れ換える

	cmp	ebx,'RAHP'	;RUN386 funciton / 'PHAR'
	je	.run386
	cmp	ebx,'XDJF'	;FM TOWNS un-documented funciton / 'FJDX'
	je	.fujitsu
	cmp	ebx,'F386'	;Free386 funciton
	je	.free386

	;DOS Version の取得
	jmp	call_V86_int21_iret	;get DOS Version

.run386:
	V86_INT	21h

	;
	;Phar Lap バージョン情報
	;	テスト値：EAX=44581406  EBX=4A613231  ECX=56435049  EDX=0
	mov	ebx, [cs:pharlap_version]	; '12Ja' or '22d '
	mov	ecx, 'IPCV'			;="VCPI" / 他' DOS','DPMI' があるが対応してない
	xor	edx, edx			;edx = 0
	iret

.fujitsu:
	mov	eax, 'XDJF'	; 'FJDX'
	mov	ebx, 'neK '	; ' Ken'
	mov	ecx, 40633300h	; '@c3', 0
	iret

.free386:
	mov	al,Major_ver	;Free386 メジャバージョン
	mov	ah,Minor_ver	;Free386 マイナーバージョン
	mov	ebx,F386_Date	;日付
	mov	ecx,0		;reserved
	mov	edx,' ABK'	;for Free386 check, 4b424120h
	iret

;------------------------------------------------------------------------------
;・プログラム終了  AH=00h,4ch
;------------------------------------------------------------------------------
proc8 int_21h_00h
	xor	al,al		;リターンコード = 0 / DOS互換
proc32 int_21h_4ch
	add	esp,12		;スタック除去
	jmp	exit_32		;DOS-Extender 終了処理

	;★本来はここに DOS_Extender 終了処理が入る

;------------------------------------------------------------------------------
;・LDT内にセレクタを作成しメモリを確保  AH=48h
;------------------------------------------------------------------------------
proc32 int_21h_48h
	push	esi
	push	edi
	push	ecx
	push	ebx
	push	ds

	push	F386_ds
	pop	ds

	mov	ecx,ebx		;ecx = 要求ページ数
	call	alloc_RAM
	jc	.fail		;失敗?

	call	search_free_LDTsel	;空きLDT検索
	test	eax,eax			;戻り値確認
	jz	.fail			;失敗?

	dec	ebx		;サイズ -1
	mov	edi,[work_adr]	;ワークアドレス
	mov	[edi  ],esi	;ベースアドレス
	mov	[edi+4],ebx	;limit
	mov	d [edi+8],0200h	;R/W 386
	push	eax
	call	make_selector_4k	;セレクタ作成 / eax = セレクタ
	pop	eax

	pop	ds
	pop	ebx
	pop	ecx
	pop	edi
	pop	esi
	clear_cy
	iret


	align	4
.fail:	call	get_maxalloc	;eax = 最大割り当てメモリ量(page)
	mov	ebx,eax		;ebx に設定
	mov	eax,8		;エラーコード
	pop	ds
	pop	ecx		;ebx 読み捨て
	pop	ecx
	pop	edi
	pop	esi
	set_cy
	iret


;------------------------------------------------------------------------------
;・LDT内のセレクタを削除しメモリを解放  AH=49h
;------------------------------------------------------------------------------
; ※メモリ解放をしていない
proc32 int_21h_49h
	
	push	eax
	push	ebx
	push	ds

	push	F386_ds
	pop	ds

	mov	eax, es			;eax = 引数セレクタ
	call	sel2adr			;アドレス変換
	and	b [ebx + 5],7fh		;P(存在) bit を 0 クリア

	xor	eax,eax			;eax = 0
	mov	  es,ax			;es  = 0

	pop	ds
	pop	ebx
	
	pop	eax
	clear_cy
	iret


;------------------------------------------------------------------------------
;・セレクタの大きさ変更  AH=4ah
;------------------------------------------------------------------------------
;  in	 es = selector
;	ebx = new page size
;
;	incompatible: not free memory
;	非互換: メモリ解放機能なし
;
proc32 int_21h_4ah
	push	eax
	push	ebx
	push	ecx
	push	edx
	push	esi
	push	edi
	push	ds
	push	fs

	push	F386_ds
	pop	ds
	push	ALLMEM_sel
	pop	fs

	mov	edi,ebx			;edi = 変更後サイズ(値保存)
	mov	eax,es			;eax = 引数セレクタ
	verr	ax			;読み込めるセレクタ？
	jnz	.not_exist

	lsl	edx,eax			;現在のリミット値
	inc	edx			;ebx = size
	shr	edx,12			;size [page]
	sub	ebx,edx			;変更後 - 変更前
	jb	.decrease		;縮小なら jmp
	je	.ret			;同じなら変更なし
	mov	ecx,ebx			;ecx = 増加ページ数

	mov	eax,es			;eax = セレクタ
	call	get_selector_last	;eax = セレクタの最終リニアアドレス
	mov	esi,eax			;esi = eax

	; 割当先にすでにページが存在すれば、
	; その部分に物理メモリ割当済とみなす。
	mov	edx, [page_dir_ladr]

.check_page_table:
	mov	ebx, esi
	shr	ebx, 24 - 4
	and	ebx, 0ffch
	mov	ebx, [fs:edx + ebx]	; ebx = page table physical address
	test	bl, 1			; check Present bit
	jz	.check_end
	and	ebx, 0fffff000h

	mov	eax, esi
	shr	eax, 12 - 2
	and	eax, 0ffch
	mov	eax, [fs:ebx + eax]
	test	al, 1			; check Present bit
	jz	.check_end

	add	esi, 1000h		; Add 4KB
	dec	ecx			; pgaes--
	jnz	short .check_page_table
	jmp	short .alloc_end

.check_end:
					;in  esi = 貼り付け先ベースアドレス
	call	get_maxalloc_with_adr	;out eax = 割り当て可能数, ebx=テーブル用ページ数
	cmp	eax,ecx			;空き - 必要量
	jb	.fail			;足りなければ失敗

					;in  esi = 貼り付け先ベースアドレス
					;    ecx = 貼り付けるページ数
	call	alloc_RAM_with_ladr	;メモリ割り当て
	jc	.fail			;out esi = esi + ecx*4K

.alloc_end:
	dec	edi			;edi = 変更後リミット値
	mov	eax,es			;
	mov	edx,edi			;edx = 変更後リミット値
	call	sel2adr			;
	shr	edx,16			;bit 31-16
	mov	al,[ebx + 6]		;
	mov	[ebx],di		;bit 15-0
	and	al,0f0h			;セレクタ情報
	and	dl,00fh			;bit 19-16
	or	al,dl			;値を混ぜる
	mov	[ebx + 6],al		;

	call	selector_reload		;全セレクタリロード

.ret:	pop	fs
	pop	ds
	pop	edi
	pop	esi
	pop	edx
	pop	ecx
	pop	ebx
	pop	eax
	clear_cy
	iret

.not_exist:
	mov	eax, 9
	jmp	short .fail2

.fail:	call	get_maxalloc_with_adr
	mov	ebx, eax
	mov	eax, 8
.fail2:	pop	fs
	pop	ds
	pop	edi
	pop	esi
	pop	edx
	pop	ecx
	add	esp,8
	set_cy
	iret

.decrease:
	; メモリは開放しないが、OpenWatcomにて
	; セレクタサイズを参照してメモリ割当要求をしてくるので、
	; セレクタサイズは減らしておく。

	; セレクタサイズを減らす
	mov	edi,ebx		;edi = 減少pageサイズ
	add	edx,ebx		;edx = 変更後pageサイズ
	dec	edx		;size to limit

	mov	eax,es		;eax = セレクタ値
	call	sel2adr		;ebx = ディスクリプタデータのアドレス

	mov	al,[ebx+6]	;セレクタ m+6
	mov	[ebx],dx	;bit 15-0
	shr	edx,16		;右シフト
	and	al,0f0h		;
	and	dl,00fh		;bit 19-16
	or	al,dl		;値合成
	mov	[ebx+6],al	;値設定

	call	selector_reload	;全セレクタのリロード
	jmp	.ret


;******************************************************************************
;・DOS-Extender functions  AH=25h,35H
;******************************************************************************
proc32 DOS_Extender_fn
	push	eax			;

	cmp	al,DOSX_fn_MAX		;テーブル最大値
	ja	.chk_02			;それ以上なら jmp

	movzx	eax,al				;機能番号
	mov	eax,[cs:DOSExt_fn_table +eax*4]	;ジャンプテーブル参照

	xchg	[esp],eax		;eax復元 & ジャンプ先記録
	ret				;テーブルジャンプ


	align	4
.chk_02:
	sub	al,0c0h			;C0h-C3h
	cmp	al,003h			;chk ?
	ja	.no_func		;それ以上なら jmp

	movzx	eax,al				;機能番号 (al)
	mov	eax,[cs:DOSExt_fn_table2+eax*4]	;ジャンプテーブル参照

	xchg	[esp],eax		;呼び出し
	ret				;


	align	4
.no_func:		;未知のファンクション
	pop	eax
	iret



;------------------------------------------------------------------------------
; Not support
;------------------------------------------------------------------------------
DOSX_fn_2512h:		;ディバグのためのプログラムロード
DOSX_fn_2516h:		;Ver2.2以降  自分自身のメモリをLDTから全て解放(?)
	set_cy
	iret

;------------------------------------------------------------------------------
;・未知のファンクション
;------------------------------------------------------------------------------
proc32 DOSX_unknown
	mov	eax,0a5a5a5a5h		;DOS-Extender のマニュアルの記述どおり
	set_cy
	iret

;------------------------------------------------------------------------------
;・V86←→Protect データ構造体のリセット  AX=2501h
;------------------------------------------------------------------------------
proc32 DOSX_fn_2501h
	push	ds

	push	F386_ds
	pop	ds

	call	clear_gp_buffer_32	; Reset GP buffer
	call	clear_sw_stack_32	; Reset CPU mode change stack

	pop	ds
	clear_cy
	iret


;------------------------------------------------------------------------------
;・Protect モードの割り込みベクタ取得  AX=2502h
;------------------------------------------------------------------------------
proc32 DOSX_fn_2502h
	push	ecx
	push	ds

	movzx	ecx,cl		;0 拡張 mov
	push	F386_ds	;
	pop	ds		;ds load

%if ((HW_INT_MASTER < 20h) || (HW_INT_SLAVE < 20h))
	cmp	cl,20h		;
	ja	.normal		;通常の処理

	lea	ecx,[intr_table + ecx*8]
	mov	ebx,[ecx  ]	;オフセット
	mov	 es,[ecx+4]	;セレクタ

	pop	ds
	pop	ecx
	clear_cy
	iret

	align	4
.normal:
%endif

	shl	ecx,3		;ecx = ecx*8
	add	ecx,[IDT_adr]	;IDT先頭加算

	mov	ebx,[ecx+4]	;bit 31-16
	mov	 bx,[ecx  ]	;bit 15-0
	mov	 es,[ecx+2]	;セレクタ値

	pop	ds
	pop	ecx
	clear_cy
	iret


;------------------------------------------------------------------------------
;・リアル(V86) モードの割り込みベクタ取得  AX=2503h
;------------------------------------------------------------------------------
proc32 DOSX_fn_2503h
	push	ds
	push	ecx

	movzx	ecx,cl		;0 拡張ロード

	mov	bx,DOSMEM_sel	;DOS メモリセレクタ
	mov	ds,bx		;ds load
	mov	ebx,[ecx*4]	;000h-3ffh の割り込みテーブル参照

	pop	ecx
	pop	ds
	clear_cy
	iret


;------------------------------------------------------------------------------
;・Protect モードの割り込みベクタ設定  AX=2504h
;------------------------------------------------------------------------------
; in 	cl     = interrupt number
;	ds:edx = entry point
;
proc32 DOSX_fn_2504h
	push	eax
	push	ecx
	push	ds

	push	F386_ds
	pop	ds

	movzx	ecx,cl

%if ((HW_INT_MASTER < 20h) || (HW_INT_SLAVE < 20h))
	cmp	cl,20h		;
	ja	.normal		;通常の処理

	lea	ecx,[intr_table + ecx*8]	;テーブルオフセット
	mov	eax,[esp]			;ax = 割り込み先 ds

	mov	[ecx  ],edx	;オフセット
	mov	[ecx+4],eax	;セレクタ

	pop	ds
	pop	ecx
	pop	eax
	clear_cy
	iret

	align	4
.normal:
%endif

	shl	ecx,3			;ecx = ecx*8
	add	ecx,[IDT_adr]		;IDT先頭加算
	mov	eax,[esp]		;ax = 割り込み先 ds

	mov	[ecx  ],dx		;bit 15-0
	mov	[ecx+2],ax		;セレクタ値
	shr	edx,16			;上位16bit
	mov	[ecx+6],dx		;bit 31-16

	pop	ds
	pop	ecx
	pop	eax
	clear_cy
.exit:	iret


;------------------------------------------------------------------------------
;・リアル(V86) モードの割り込みベクタ設定  AX=2505h
;------------------------------------------------------------------------------
; in	 cl = interrupt number
;	ebx = handler address / SEG:OFF
;
proc32 DOSX_fn_2505h
	call	set_V86_vector
	clear_cy
	iret

proc32 set_V86_vector
	push	ds
	push	ebx
	push	ecx

	movzx	ecx,cl		;0 拡張ロード

	push	DOSMEM_sel	;DOS メモリセレクタ
	pop	ds		;ds load
	mov	[ecx*4],ebx	;000h-3ffh の割り込みテーブルに設定

	mov	ebx,offset RVects_flag_tbl	;ベクタ書き換えフラグテーブル
	add	ebx,[cs:top_ladr]		;Free 386 の先頭リニアアドレス
	bts	[ebx],ecx			;int 書き換えをフラグをセット
	;↑ebx を先頭にメモリをビット列と見なし、
	;　そのビット列の ecx bit を 1 にセットする命令。

	pop	ecx
	pop	ebx
	pop	ds
.exit:	ret

;------------------------------------------------------------------------------
;・常にプロテクトモードで発生する割り込みの設定  AX=2506h
;------------------------------------------------------------------------------
proc32 DOSX_fn_2506h
	push	ebx
	push	ecx
	push	esi
	push	ds

	push	F386_ds
	pop	ds

	movzx	ecx,cl

	mov	ebx,[V86_cs]		;V86 ベクタ CS
	shl	ebx,16			;上位へ
	mov	esi,[rint_labels_adr]	;int 0    の hook ルーチンアドレス
	lea	 bx,[esi+ecx*4]		;int cl 番の hook ルーチンアドレス
	call	set_V86_vector		;ベクタ設定

	pop	ds
	pop	esi
	pop	ecx
	pop	ebx
	jmp	DOSX_fn_2504h		;プロテクトモードの割り込みベクタ設定


;------------------------------------------------------------------------------
;・リアル(V86)モードとプロテクトモードの割り込み設定　AX=2507h
;------------------------------------------------------------------------------
proc32 DOSX_fn_2507h
	;call	set_V86_vector
	;jmp	DOSX_fn_2504h	;プロテクトモードの割り込み設定

		;↓

	push	offset DOSX_fn_2504h
	jmp	set_V86_vector


;------------------------------------------------------------------------------
;・セグメントセレクタのベースリニアアドレスを取得  AX=2508h
;------------------------------------------------------------------------------
proc32 DOSX_fn_2508h
	verr	bx		;セレクタが有効か?
	jnz	short .void	;無効

	push	eax
	push	ebx

	movzx	eax,bx		;eax = セレクタ
	call	sel2adr		;ディスクリプタアドレスに変換 ->ebx

	mov	ecx,[cs:ebx+4]	;bit 31-24
	mov	eax,[cs:ebx+2]	;bit 23-0
	and	ecx,0ff000000h	;マスク
	and	eax, 00ffffffh	;
	or	ecx,eax		;値合成

	pop	ebx
	pop	eax
	clear_cy
	iret

.void:
	mov	eax, 9		;セレクタが不正
	set_cy
	iret



;------------------------------------------------------------------------------
;・リニアアドレスから物理アドレスへの変換　AX=2509h
;------------------------------------------------------------------------------
proc32 DOSX_fn_2509h
	push	ecx
	push	edx
	push	ds
	push	es

	push	F386_ds
	pop	ds			;ds 設定
	push	ALLMEM_sel
	pop	es			;全メモリアクセスセレクタ

	mov	ecx,ebx			;ecx = リニアアドレス
	shr	ecx,20			;bit 31-20 取り出し
	and	 cl,0fch		;bit 21,20 を 0 クリア
	add	ecx,[page_dir_ladr]	;ページディレクトリ
	mov	edx,[es:ecx]		;テーブルからデータを引く

	test	edx,edx			;値チェック
	jz	.error			;0 なら jmp
	and	edx,0fffff000h		;bit 0-11 clear

	mov	ecx,ebx			;ecx = リニアアドレス
	shr	ecx,10			;bit 31-10 取り出し
	and	ecx,0ffch		;bit 31-22,11,10 をクリア

	mov	ecx,[es:edx+ecx]	 ;ページテーブから目的のページを引く
	test	 cl,1			 ;bit 0 ?  (P:存在ビット)
	jz	.error			 ;if 0 jmp

	mov	edx,ebx			;edx = リニアアドレス
	and	ecx,0fffff000h		;bit 31-12 を取り出す
	and	edx,     0fffh		;bit 11-0
	or	ecx,edx			;値を混ぜる

	pop	es
	pop	ds
	pop	edx
	add	esp,byte 4		;ecx = 戻り値 なので pop しない
	clear_cy
	iret


	align	4
.error:
	pop	es
	pop	ds
	pop	edx
	pop	ecx
	set_cy
	iret


;------------------------------------------------------------------------------
;・物理アドレスのマッピング　AX=250ah
;------------------------------------------------------------------------------
proc32 DOSX_fn_250ah
	push	ds
	push	esi
	push	edi
	push	edx
	push	ecx
	push	ebx	;スタック順番変更不可！

	push	F386_ds
	pop	ds

	mov	ebx,es		;指定セレクタロード
	pushf			;*
	push	cs		;* セレクタベースアドレス取得
	call	DOSX_fn_2508h	;*
	mov	eax,ecx		;eax = ベースアドレス
	lsl	ebx,ebx		;ebx = リミット値
	inc	ebx		;ebx = サイズ
	mov	edi,ebx		;edi にも
	add	ecx,ebx		;ecx = セレクタの一番後ろ
	shr	edi,12		;edi = page単位のサイズ

	test	ecx,0fffh	;下位12ビットチェック
	jnz	.fail0		;ページ単位割りつけでないものはジャンプ

	mov	esi,ecx			;esi = 張りつけ先リニアアドレス
	mov	ecx,[esp+4]		;ecx = 張りつけるページ数
	mov	edx,[esp]		;edx = 張りつける物理アドレス
	add	edi,ecx			;edi = 処理後のサイズ
	call	set_physical_mem	;張りつけ
	jc	.fail1			;ページテーブル不足

	mov	eax,ebx			;eax = セレクタ内オフセット
	mov	ecx,edi			;ecx = 新しいサイズ
	dec	ecx			;limit値へ

	mov	ebx,es		;指定セレクタ
	mov	edx,[GDT_adr]	;GDT へのポインタ
	test	ebx,4		;セレクタ値のbit2を check
	jz	short .GDT	; 0 ならばGDT なのでこのままｼﾞｬﾝﾌﾟ
	mov	edx,[LDT_adr]	;LDT へのポインタ
.GDT:	and	ebx,0fff8h	;ディスクリプタは8byte単位なので下位3bit切捨て
	add	ebx,edx

	mov	[ebx  ],cx	;limit値 bit 15-0
	mov	dl,[ebx+6]	;DT+6 読み出し
	shr	ecx,16		;右シフト
	and	dl,0f0h		;セレクタ情報
	and	cl,00fh		;limit値 bit 19-16
	or	dl,cl		;limit値を混ぜる
	mov	[ebx+6],dl	;

	call	selector_reload	;全セレクタのリロード (hack.txt参照のこと)

	pop	ebx
	pop	ecx
	pop	edx
	pop	edi
	pop	esi
	pop	ds
	clear_cy
	iret

.fail1:	mov	eax,8	;ページテーブル不足
	jmp	short .fail
.fail0:	mov	eax,9	;セレクタが不正
.fail:	pop	ebx
	pop	ecx
	pop	edx
	pop	edi
	pop	esi
	pop	ds
	set_cy
	iret


;------------------------------------------------------------------------------
;・ハードウェア割り込みベクタの取得　AX=250ch
;------------------------------------------------------------------------------
proc32 DOSX_fn_250ch

	%ifdef USE_VCPI_8259A_API
		mov	ax,[cs:vcpi_8259m]
	%else
		mov	al,HW_INT_MASTER
		mov	ah,HW_INT_SLAVE
	%endif

	clear_cy
	iret


;------------------------------------------------------------------------------
;・リアルモードリンク情報の取得　AX=250dh
;------------------------------------------------------------------------------
; out	   eax = CS:IP   - far call routine address
;	   ecx = buffer size
;	   ebx = Seg:Off - 16bit buffer address
;	es:edx = buffer protect mode address
;
proc32 DOSX_fn_250dh
	mov	ebx, d [cs:user_cbuf_adr16]
	movzx	ecx, b [cs:user_cbuf_pages]
	shl	ecx, 12				; page to byte

	mov	eax, DOSMEM_sel
	mov	 es, ax
	mov	edx, d [cs:user_cbuf_ladr]

	mov	 ax, [cs:V86_cs]
	shl	eax, 16
	mov	 ax, offset callf32_from_V86

	clear_cy
	iret


;------------------------------------------------------------------------------
;・プロテクトモードアドレスをリアルモードアドレスに変換　AX=250fh
;------------------------------------------------------------------------------
;	es:ebx	address
;	ecx	size
;
;	Ret:	ecx=seg:off
;
proc32 DOSX_fn_250fh
	push	eax
	push	ebp
	push	esi
	push	edi
	push	ecx
	push	ebx	;スタック順番変更不可！
	cmp	ebx, 0ffffh
	ja	.fail		;

	mov	ebx, es		;in : bx=selector
	callint	DOSX_fn_2508h	;セレクタベースアドレス取得
	jc	.fail		;out: ecx=base

	mov	ebx, [esp]	;ebx = offset
	mov	edi, [esp+4]	;edi = size
	add	ecx, ebx	;ecx = ebx = base + offset
	mov	ebx, ecx	;
	and	ecx, 000000fffh	;端数
	and	ebx, 0fffff000h	;4KB単位
	add	edi, ecx	;端数をサイズに加算
	jc	.fail		;オーバーフロー

	xor	esi, esi
.loop:				;in = ebx
	callint	DOSX_fn_2509h	;物理アドレスへの変換
				;out= ecx
	cmp	ecx, 010ffefh	;リニアアドレス範囲
	ja	.fail		;DOSメモリ範囲外 なら jmp
	test	esi, esi
	jnz	.check
	mov	esi, ecx	;
	mov	ebp, ecx	;最初の物理アドレス記録
	jmp	short .step
.check:
	add	esi, 01000h	;1つ前の物理アドレス+4K
	cmp	ecx, esi	;一致するか？
	jnz	.fail		;不連続なら失敗
.step:
	add	ebx, 01000h	;リニアアドレス +4KB
	sub	edi, 01000h	;サイズ         -4KB
	ja	.loop

	;convert to real-mode seg:off
	mov	ecx, ebp
	shl	ecx, 16-4	;bit31-16 = DOS seg
	mov	 cx, [esp]	;bit15- 0 = offset

	pop	ebx
	pop	eax		;ecx 除去
	pop	edi
	pop	esi
	pop	ebp
	pop	eax
	clear_cy
	iret

.fail:
	pop	ebx
	pop	ecx
	pop	edi
	pop	esi
	pop	ebp
	pop	eax
	set_cy
	iret


;------------------------------------------------------------------------------
; far call to real mode routine //  AX=250eh
;------------------------------------------------------------------------------
; in	ebx = call far address
;	ecx = stack copy count (word)
; ret	 cy = 0	success
;	 cy = 1	fail. eax = 1 not enough real-mode stack space
;
%define	COPY_STACK_MAX	(SW_stack_size - 40h)

proc32 DOSX_fn_250eh
	start_sdiff
	pushf_x
	push_x	eax
	push_x	ecx
	push_x	ds

	push	F386_ds
	pop	ds

	lea	eax, [esp + .sdiff + 0ch]	; copy stack offset
	mov	[cv86_copy_stack], eax
	shl	ecx, 1				; ecx is copy word count
	mov	[cv86_copy_size],  ecx

	cmp	ecx, COPY_STACK_MAX
	pop_x	ds
	pop_x	ecx
	pop_x	eax
	ja	.fail
	popf_x
	end_sdiff

	push	ebx				; far call point
	push	O_CV86_FARCALL
	call	call_V86_clear_stack
	clc
	jmp	all_flags_save_iret

.fail:
	mov	eax, 1
	popf
	set_cy
	iret

;------------------------------------------------------------------------------
; far call real mode routine // AX=2510h
;------------------------------------------------------------------------------
; in	   ebx = call far address
;	   ecx = stack copy count (word)
;	ds:edx = parameter block
; ret	cy = 0	success
;	   edx = unchange
;	cy = 1	fail. eax = 1 not enough real-mode stack space
;
proc32 DOSX_fn_2510h
	start_sdiff
	push_x	es

	push	F386_ds
	pop	es

	;--------------------------------------------------
	; check copy stack size
	;--------------------------------------------------
	pushf_x
	push_x	ecx

	lea	eax, [esp + .sdiff + 0ch]
	mov	es:[cv86_copy_stack], eax	; copy stack top
	shl	ecx, 1				; ecx is copy word count
	mov	es:[cv86_copy_size],  ecx	; copy bytes

	cmp	ecx, COPY_STACK_MAX
	pop_x	ecx
	ja	.fail
	popf_x

	;--------------------------------------------------
	; set V86 segments
	;--------------------------------------------------
	movzx	eax,w [edx]
	mov	es:[cv86_ds], eax
	movzx	eax,w [edx + 02h]
	mov	es:[cv86_es], eax
	movzx	eax,w [edx + 04h]
	mov	es:[cv86_fs], eax
	movzx	eax,w [edx + 06h]
	mov	es:[cv86_gs], eax

	push_x	edx			; save parameter block pointer
	;--------------------------------------------------
	; set register and call
	;--------------------------------------------------
	push	ebx			; far call point
	push	O_CV86_FARCALL		; options

	mov	eax, [edx + 08h]	; load from parameter block
	mov	ebx, [edx + 0ch]
	mov	ecx, [edx + 10h]	;
	mov	edx, [edx + 14h]	;
	call	call_V86_clear_stack

	;--------------------------------------------------
	; save register
	;--------------------------------------------------
	; *** NOT USE eax! ***
	xchg	[esp], edx		; edx   = parameter block pointer
					; [esp] = return edx
	mov	[edx + 0ch], ebx
	mov	[edx + 10h], ecx	
	pop_x	ebx			; ebx = return edx
	mov	[edx + 14h], ebx	; save

	pushf_x
	pop_x	ebx
	mov	[edx + 08h], ebx	; save flags

	;--------------------------------------------------
	; save V86 segments
	;--------------------------------------------------
	mov	ebx, es:[cv86_ds]
	mov	[edx + 00h], bx
	mov	ebx, es:[cv86_es]
	mov	[edx + 02h], bx
	mov	ebx, es:[cv86_fs]
	mov	[edx + 04h], bx
	mov	ebx, es:[cv86_gs]
	mov	[edx + 06h], bx

	;--------------------------------------------------
	; return
	;--------------------------------------------------
	pop_x	es
	end_sdiff

	clc
	jmp	all_flags_save_iret

.fail:
	mov	eax, 1
	popf
	pop	es
	set_cy
	iret


;------------------------------------------------------------------------------
;・リアルモード割り込みの実行　AX=2511h
;------------------------------------------------------------------------------
; in	ds:edx
;	+00h w int number
;	+02h w ds
;	+04h w es
;	+06h w fs
;	+08h w gs
;	+0ah d eax
;	+0eh d edx
;
proc32 DOSX_fn_2511h
	push	es
	push	edx

	push	F386_ds
	pop	es

%if INT_HOOK && PRINT_TSUGARU
	; Debug support with emulator Tsugaru
	push	ebx
	push	ecx
	push	edx

	mov	ebx, edx
	mov	ecx, 12h
	mov	dx, 2F18h
	mov	al, 0ah
	out	dx, al

	pop	edx
	pop	ecx
	pop	ebx
%endif
	;--------------------------------------------------
	; set V86 segments
	;--------------------------------------------------
	movzx	eax,w [edx + 02h]
	mov	es:[cv86_ds], eax
	movzx	eax,w [edx + 04h]
	mov	es:[cv86_es], eax
	movzx	eax,w [edx + 06h]
	mov	es:[cv86_fs], eax
	movzx	eax,w [edx + 08h]
	mov	es:[cv86_gs], eax

	;--------------------------------------------------
	; call V86 int
	;--------------------------------------------------
	movzx	eax, byte [edx]
	push	eax			; int number
	push	O_CV86_INT

	mov	eax, [edx + 0ah]
	mov	edx, [edx + 0eh]
	call	call_V86_clear_stack

	;--------------------------------------------------
	; save register
	;--------------------------------------------------
	; stack	+00h edx	parameter block pointer
	;	+04h  es
	;
	xchg	[esp], eax		; eax = parameter block
	xchg	eax, edx		; edx = parameter block
	mov	[edx + 0eh], eax	; save return edx

	; stack	+00h eax
	;	+04h  es
	mov	eax, es:[cv86_ds]
	mov	[edx + 02h], ax
	mov	eax, es:[cv86_es]
	mov	[edx + 04h], ax
	mov	eax, es:[cv86_fs]
	mov	[edx + 06h], ax
	mov	eax, es:[cv86_gs]
	mov	[edx + 08h], ax

	pop	eax
	pop	es
	jmp	all_flags_save_iret


;------------------------------------------------------------------------------
;・エイリアスセレクタの作成　AX=2513h
;------------------------------------------------------------------------------
;	bx = エイリアスを作成するセレクタ
;	cl = ディスクリプタ内 +5 byte 目にセットする値
;	ch = bit 6 のみ意味を持ち、USE属性(16bit/32bit)を指定
;
proc32 DOSX_fn_2513h
	push	ds
	push	edx
	push	ecx
	push	ebx
	push	eax	;戻り値を直接書き込むので、最後の積む

	push	F386_ds
	pop	ds

	movzx	ebx,bx		;0 拡張ロード

	call	search_free_LDTsel	;空きセレクタ検索
	test	eax,eax			;戻り値確認
	jz	short .fail		;0 なら失敗

	mov	[esp], eax	;コピー先セレクタ（戻り値記録）

	push	ebx
	call	sel2adr		;LDT内アドレスに変換
	mov	edx,ebx		;edx = コピー先アドレス
	pop	eax		;eax = コピー元セレクタ
	call	sel2adr		;ebx = コピー元アドレス

	test	ebx, ebx
	jz	short .void
	test	b [ebx+5], 080h	;P bit
	jz	short .void

	;copy  ebx->edx
	mov	eax,[ebx]	;コピー
	mov	[edx],eax	;

	mov	eax,[ebx+4]	;
	shl	ecx,8		;シフト
	and	ecx,000407f00h	;bit 15-0  取り出し
	and	eax,0ffbf80ffh	;bit 23-16 の該当部をマスク
	or	eax,ecx		;引数の値を混ぜる
	mov	[edx+4],eax	;

	pop	eax		;eax 位置のスタック読み捨て
	pop	ebx
	pop	ecx
	pop	edx
	pop	ds
	clear_cy
	iret

.fail:	mov	eax,8
.ret:	pop	edx	; eax読み捨て
	pop	ebx
	pop	ecx
	pop	edx
	pop	ds
	set_cy
	iret

.void:
	mov	eax,9		;セレクタが不正
	jmp	short .ret


;------------------------------------------------------------------------------
;・セグメント属性の変更　AX=2514h
;------------------------------------------------------------------------------
proc32 DOSX_fn_2514h
	push	ecx
	push	ebx
	push	eax
	push	ds

	push	F386_ds
	pop	ds

	movzx	eax,bx		;eax = セレクタ
	call	sel2adr		;ebx = アドレス

	test	ebx, ebx		;範囲外のときebx=0
	jz	short .void
	test	b [ebx+5], 080h		;P bit
	jz	short .void

	mov	eax, [ebx+4]	;現在値ロード
	shl	ecx,8		;シフト
	and	ecx,000407f00h	;bit 15-0  取り出し
	and	eax,0ffbf80ffh	;bit 23-16 の該当部をマスク

	or	eax,ecx		;引数の値を混ぜる
	mov	[ebx+4],eax	;

	pop	ds
	pop	ecx
	pop	ebx
	pop	eax
	clear_cy
	iret

.void:
	mov	eax,9		;セレクタが不正
	pop	ds
	pop	ebx		;eax読み捨て
	pop	ebx
	pop	ecx
	set_cy
	iret


;------------------------------------------------------------------------------
;・セグメント属性の取得　AX=2515h
;------------------------------------------------------------------------------
proc32 DOSX_fn_2515h
	push	ebx
	push	eax

	movzx	eax,bx		;eax = セレクタ
	call	sel2adr		;ebx = アドレス
	test	ebx, ebx	;範囲外のときebx=0
	jz	short .void

	mov	cx,[cs:ebx+5]	;USE / Type ロード

	pop	eax
	pop	ebx
	clear_cy
	iret

.void:
	mov	eax,9		;セレクタが不正
	pop	ds
	pop	ebx		;eax読み捨て
	pop	ebx
	set_cy
	iret


;------------------------------------------------------------------------------
;AX=2517h: GET INFO ON DOS DATA BUFFER, Phar Lap v2.1c+
;------------------------------------------------------------------------------
;out es:ebx = protect mode buffer address
;	ecx = real mode address, Seg:Off
;	edx = size (byte)
;
proc32 DOSX_fn_2517h
	mov	eax, DOSMEM_sel
	mov	 es, ax
	mov	ebx, d [cs:user_cbuf_ladr]

	mov	ecx, d [cs:user_cbuf_adr16]
	movzx	edx, b [cs:user_cbuf_pages]
	shl	edx, 12				; page to byte

	clear_cy
	iret


;------------------------------------------------------------------------------
;・DOSメモリブロックアロケーション　AX=25c0h
;------------------------------------------------------------------------------
proc32 DOSX_fn_25c0h
	mov	ah,48h
	jmp	call_V86_int21_iret


;------------------------------------------------------------------------------
;・DOSメモリブロックの解放　AX=25c1h
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
;・MS-DOSメモリブロックのサイズ変更　AX=25c2h
;------------------------------------------------------------------------------
proc32 DOSX_fn_25c1h
	push	eax
	mov	ah,49h		; free memory block
	jmp	short DOSX_fn_25c2h.step

proc32 DOSX_fn_25c2h		; resize memory block
	push	eax
	mov	ah,49h
.step:
	V86_INT	21h
	jc	.fail

	pop	eax		; success
	clear_cy
	iret

.fail:	add	esp, 4		; remove eax // eax = error code
	set_cy
	iret


;------------------------------------------------------------------------------
;・DOSプログラムを子プロセスとして実行  AX=25c3h
;------------------------------------------------------------------------------
;DOSX_fn_25c3h
;	jmp	int_21h_4bh		;int 21h / 4bh と同じ
;
;//////////////////////////////////////////////////////////////////////////////
