;******************************************************************************
;　Segment and memory routine	for Free386
;******************************************************************************
;[TAB=8]
;
;
%include	"macro.inc"
%include	"f386def.inc"
%include	"free386.inc"
%include	"memory.inc"

;------------------------------------------------------------------------------

global	make_selector
global	make_selector_4k
global	set_physical_mem
global	alloc_DOS_mem
global	alloc_RAM
global	alloc_RAM_with_ladr

global	map_memory		;物理メモリを配置しセレクタを作成、テーブル参照
global	make_aliases		;セレクタのエイリアスを作成（テーブル参照）
global	make_alias		;セレクタのエイリアスを作成
global	get_maxalloc		;最大割り当て可能メモリ(page)取得
global	get_maxalloc_with_adr	;最大割り当て可能メモリ(page)取得
global	get_selector_last	;セレクタ最後尾リニアアドレス(+1)取得
global	sel2adr			;セレクタ値 to アドレス変換
global	search_free_LDTsel	;空きLDTセレクタの検索
global	selector_reload		;全データセレクタのリロード

;******************************************************************************
segment	text32 class=CODE align=4 use32
;******************************************************************************
;------------------------------------------------------------------------------
;●メモリセグメントを作成します
;------------------------------------------------------------------------------
;void make_selector(int selctor,struct mem_descriptor *memd)
;
;	selctor	＝ セレクタ値（作成するセレクタ値）
;
;struct	mem_descriptor
;{
;	int	base;	// リニア空間ベースオフセット
;	int	limit;	// リミット値（単位 byte）
;	char	level;	// 特権レベル(0～3)
;	char	type;	// メモリセグメントタイプ（get_gdtのﾀｲﾌﾟ定義参照）
;};		   	//  必ず 00h～0fh(0～15) の間の値であること。
;			//  ↑追加：bit 4 が 1 ならば 286形式のセグメント作成
;	eax = selector
;	edi = 構造体 offset
;
;mtask のものとは非互換！！
	align	4
make_selector:
	push	ebx
	push	ecx
	push	edx
	push	edi
	push	es

	mov	bx,F386_ds	;F386 を示すセレクタ
	mov	es,ebx		;

	mov	ebx,eax		;指定ｾﾚｸﾀ値
	;mov	edi,[ebp+0ch]	;ﾃﾞｨｸﾘﾌﾟﾀ型を示す構造体ｵﾌｾｯﾄ

	mov	ecx,[es:GDT_adr] ;GDT へのポインタ
	test	ebx,4		 ;ｾﾚｸﾀ値のﾋﾞｯﾄ2をﾁｪｯｸ
	jz	short .GDT	 ; 0 ならばGDT なのでこのまま jmp
	mov	ecx,[es:LDT_adr] ;LDT へのポインタ
.GDT:
	and	ebx,0fff8h	;DTは8byte単位なので下位3bit切捨て
	add	ebx,ecx

	mov	edx,[edi+4]	;リミット値ロード
	mov	[es:ebx],dx	;リミット値をテーブルにセットbit0～15
	and	edx,0f0000h	;リミット値の bit16～19 を取り出す

	test	b [edi+9],10h	;286形式？
	jnz	.s286		;bit が 立ってれば jmp
	or	edx,400000h	;属性 386形式
.s286:
	mov	eax,[edi]	;base offset
	mov	[es:ebx+2],ax	;base bit0～15
	mov	ecx,eax
	shr	ecx,8		;baseの bit16～23
	and	eax,0ff000000h	;baseの bit24～31
	mov	dl,ch		;bit 16～23 set
	or	edx,eax		;bit 24～31 set

	mov	ax,[edi+8]	;特権レベル(dl)とseg-type(dh)をロード
	and	ah,0fh		;Type フィールドの値マスク
	shl	al,5		;bit5･6 の位置にもってくる
	or	al,ah		;特権レベルとセグメントタイプを混ぜる
	or	al,90h		;存在する(80h) 存在ビット(Pビット) を 1に
	mov	dh,al		;記録用regに格納   　＋DT1(mem 形式):10h
	mov	[es:ebx+4],edx	;テーブルに記録

	pop	es
	pop	edi
	pop	edx
	pop	ecx
	pop	ebx
	ret


;------------------------------------------------------------------------------
;●メモリセグメントを作成します（4KB 単位）
;------------------------------------------------------------------------------
;void make_selector(int selctor,struct mem_descriptor *memd)
;
;	selctor	＝ セレクタ値（作成するセレクタ値）
;
;struct	mem_descriptor
;{
;	int	base;	// リニア空間ベースオフセット
;	int	limit;	// リミット値（単位 4 Kbyte）
;	char	level;	// 特権レベル(0～3)
;	char	type;	// メモリセグメントタイプ（get_gdtのﾀｲﾌﾟ定義参照）
;};		   	//  必ず 00h～0fh(0～15) の間の値であること。
;			//  ↑追加：bit 4 が 1 ならば 286形式のセグメント作成
;	eax = selector
;	edi = 構造体 offset
;
	align 4
make_selector_4k:
	push	ebx
	push	ecx
	push	edx
	push	edi
	push	es

	mov	ebx,F386_ds	;F386 を示すセレクタ
	mov	 es,ebx		;

	mov	ebx,eax		;指定ｾﾚｸﾀ値
	;mov	edi,[ebp+0ch]	;ﾃﾞｨｸﾘﾌﾟﾀ型を示す構造体ｵﾌｾｯﾄ

	mov	ecx,[es:GDT_adr] ;GDT へのポインタ
	test	ebx,4		 ;ｾﾚｸﾀ値のﾋﾞｯﾄ2をﾁｪｯｸ
	jz	short .GDT	 ; 0 ならばGDT なのでこのままｼﾞｬﾝﾌﾟ
	mov	ecx,[es:LDT_adr] ;LDT へのポインタ
.GDT:
	and	ebx,0fff8h	;ﾃﾞｨｽｸﾘﾌﾟﾀは 8ﾊﾞｲﾄ単位なので下位3ﾋﾞｯﾄ切捨て
	add	ebx,ecx

	mov	edx,[edi+4]	;ﾘﾐｯﾄ値
	mov	[es:ebx],dx	;ﾘﾐｯﾄ値をﾃｰﾌﾞﾙにｾｯﾄ bit0～15
	and	edx,0f0000h	;ﾘﾐｯﾄ値の bit16～19 を取り出す
	or	edx,800000h	;属性 4KB単位のリミット

	test	b [edi+9],10h	;286形式？
	jnz	.s286		;bit が 立ってれば jmp
	or	edx,400000h	;属性 386形式
.s286:
	mov	eax,[edi]	;ﾍﾞｰｽｵﾌｾｯﾄﾛｰﾄﾞ
	mov	[es:ebx+2],ax	;ﾍﾞｰｽ bit0～15
	mov	ecx,eax
	shr	ecx,8		;ﾍﾞｰｽの bit16～23
	and	eax,0ff000000h	;ﾍﾞｰｽの bit24～31
	mov	dl,ch		;bit 16～23ｾｯﾄ
	or	edx,eax		;bit 24～31ｾｯﾄ

	mov	ax,[edi+8]	;特権ﾚﾍﾞﾙ(dl) と ｾｸﾞﾒﾝﾄﾀｲﾌﾟ(dh)をﾛｰﾄﾞ
	and	ah,0fh		;Type フィールドの値マスク
	shl	al,5		;bit5･6 の位置にもってくる
	or	al,ah		;特権レベルとセグメントタイプを混ぜる
	or	al,90h		;存在する(80h) 存在ビット(Pビット) を 1に
	mov	dh,al		;記録用ﾚｼﾞｽﾀに格納   　＋DT1(mem 形式):10h
	mov	[es:ebx+4],edx	;ﾃｰﾌﾞﾙに記録

	pop	es
	pop	edi
	pop	edx
	pop	ecx
	pop	ebx
	ret


	align	4
;------------------------------------------------------------------------------
;●物理メモリを指定リニアアドレスに配置する
;------------------------------------------------------------------------------
;	esi = 張りつけ先リニアアドレス (4KB Unit)
;	edx = 張りつける物理アドレス   (4KB Unit)
;	ecx = 張りつけるページ数
;
;	Ret	Cy = 0 成功
;		Cy = 1 ページテーブルが足りない
;
proc set_physical_mem
	test	ecx,ecx		;割りつけページ数が 0
	jz	NEAR .ret	;何もせず ret

	pusha
	push	es
	mov	eax,ALLMEM_sel		;全メモリアクセスセレクタ
	mov	 es,eax			;es にロード
	or	 dl,7			;ページの bit0-2 = 存在, R/W, Level 0-3
	mov	ebp,1000h		;const
	jmp	short .next_page_table	;ループスタート

	align	4
.loop_start:
	;edi = page table top
	and	edi,0xfffff000		;table dir entry
	mov	ebx,esi			;linear address
	shr	ebx,10
	and	ebx,0xffc
	or	edi,ebx
	mov	eax,0fffh		;const
	jmp	.lp0

	align	4
	;/// main loop ////////////////////////////
	; ecx = 張りつけるページ数
	; edx = 張りつける物理メモリ
	; edi = リニアアドレスに対応したページエントリのアドレス
	; esi = リニアアドレス
.loop:
	test	edi,eax	;=0fffh		;if オフセットが 0 に戻ったら
	jz	short .next_page_table	;  新たなページテーブル作成 (jmp)

.lp0:	mov	[es:edi],edx		;ページをエントリ
	add	edi,byte 4		;テーブル内オフセット
	add	edx,ebp ;=1000h		;物理アドレス       + 4K
	add	esi,ebp ;=1000h		;張りつけ先アドレス + 4K

	loop	.loop			;割りつけページ数分、ループ
	;///////////////////////////// end loop ///
	pop	es
	popa
.ret:	clc
	ret

	align	4
.next_page_table:
	; must save reg : ecx,edx,esi
	mov	ebx,esi			;ebx = 張りつけ先リニアアドレス
	shr	ebx,20			;bit 31-20
	and	 bl, 0fch		;bit 21,20 のクリア
	add	ebx,[page_dir_ladr]	;page dir
	mov	edi,[es:ebx]		;リニアアドレスを参照
	test	edi,edi			;if entry != 0 （テーブルが存在する）
	jnz	short .loop_start	;  jmp

	;/// 新たなページテーブルの作成 ///
	mov	eax,[free_RAM_pages]	;空き物理メモリ先頭
	test	eax,eax			;値確認
	jz	.no_free_memory		;0 なら jmp
	dec	eax			;残りページ数を減算
	mov	[free_RAM_pages],eax	;値を記録

	;/// new entry 'page table' to 'page dir' ///
	mov	eax,[free_RAM_padr]	;空き物理メモリ先頭
	mov	edi,eax			;ediにsave
	or	 al,7			;page entry
	mov	[es:ebx],eax		;entry
	add	eax,ebp	;=1000h		;4KB step
	xor	 al,al			;下位bit clear
	mov	[free_RAM_padr],eax	;空き物理メモリ

	;/// zero clear 張りつけたテーブルを0クリアする ///
	push	ecx
	push	edi
	;
	mov	ecx,1000h /4		;塗りつぶし回数
	xor	eax,eax			;0 クリア
	rep	stosd			;塗りつぶし
	;
	pop	edi
	pop	ecx
	jmp	.loop_start


	align	4
.no_free_memory:	;ページテーブル作成のためのメモリが不足
	pop	es
	popa
	stc			;キャリーセット
	ret



;------------------------------------------------------------------------------
;●DOS RAM アロケーション
;------------------------------------------------------------------------------
;	ecx = 貼りつけるページ数
;
;	Ret	Cy = 0 成功
;			eax = 割り当てたページ数
;			esi = 割り当て先頭リニアアドレス
;		Cy = 1 ページテーブルが足りない (esi破壊)
	
	align	4
alloc_DOS_mem:
	push	ebx
	push	ecx
	push	edx

	mov	eax,[DOS_mem_pages]
	test	eax,eax
	jz	.no_dos_mem		;DOSメモリなし

	cmp	eax,ecx			;空きページ数 - 要求ページ数
	jae	.enough
	mov	ecx,eax			;足りなければ、あるだけ貼り付け
.enough:
	mov	edx,[DOS_mem_ladr]	;DOSメモリ
	mov	esi,[free_liner_adr]	;割りつけ先アドレス
	call	set_physical_mem	;メモリ割り当て
	jc	.no_free_memory		;メモリ不足エラー

	sub	[DOS_mem_pages] ,ecx	;空きメモリページ数減算
	mov	eax, ecx
	shl	ecx, 12			;byte 単位へ
	add	[DOS_mem_ladr]  ,ecx	;空きDOSメモリ
	add	[free_liner_adr],ecx	;空きメモリアドレス更新

	clc
.exit:
	pop	edx
	pop	ecx
	pop	ebx
	ret

.no_dos_mem:
	xor	eax, eax
	mov	esi, [free_liner_adr]
	clc
	jmp	short .exit

.no_free_memory:
	stc
	jmp	short .exit


	align	4
;------------------------------------------------------------------------------
;●RAM アロケーション
;------------------------------------------------------------------------------
;	ecx = 貼りつけるページ数
;
;	Ret	Cy = 0 成功
;			esi = 割り当て先頭リニアアドレス
;		Cy = 1 ページテーブルまたはメモリが足りない (esi破壊)
;
	align	4
alloc_RAM:
	push	eax
	push	ebx
	push	ecx
	push	edx

	test	ecx,ecx
	jz	.no_alloc

	mov	esi, [free_liner_adr]	;割りつけ先アドレス
	call	get_maxalloc_with_adr	;eax = 最大割り当て可能メモリページ数
					;ebx = ページテーブル用に必要なページ数

	cmp	eax,ecx			;空きページ数 - 要求ページ数
	jb	.no_free_memory		;小さければメモリ不足

	mov	edx,[free_RAM_padr]	;空き物理メモリ
	;mov	esi,[free_liner_adr]	;割りつけ先アドレス
	shl	ebx,12			;ページテーブル用に必要なメモリ(byte)
	add	edx,ebx			;割りつける物理メモリをずらす
	call	set_physical_mem	;メモリ割り当て
	jc	.no_free_memory		;メモリ不足エラー

	sub	[free_RAM_pages],ecx	;空きメモリページ数減算
	shl	ecx,12			;byte 単位へ
	add	[free_RAM_padr] ,ecx	;空き物理メモリをずらす

.no_alloc:
	add	esi, ecx				;空きメモリアドレス更新
	add	esi,LADR_ROOM_size + (LADR_UNIT -1)	;端数切上げ
	and	esi,0ffc00000h				;下位 20ビット切捨て (4MB の倍数に)
	add	[free_liner_adr] ,esi			;空きアドレス更新

	clc		;キャリークリア
.exit:
	pop	edx
	pop	ecx
	pop	ebx
	pop	eax
	ret

	;ページテーブル作成のためのメモリが不足
.no_free_memory:
	stc
	jmp	short .exit

;------------------------------------------------------------------------------
;●RAM アロケーション
;------------------------------------------------------------------------------
;	esi = 貼り付ける先リニアアドレス
;	ecx = 貼りつけるページ数
;
;	Ret	Cy = 0 成功
;			esi = 割り当て後リニアアドレス = esi + ecx*4KB
;		Cy = 1 ページテーブルまたはメモリが足りない (esi破壊)
;
	align	4
alloc_RAM_with_ladr:
	push	eax
	push	ebx
	push	ecx
	push	edx

	test	ecx,ecx
	jz	.no_alloc

	call	get_maxalloc_with_adr	;eax = 最大割り当て可能メモリページ数
					;ebx = ページテーブル用に必要なページ数
	cmp	eax,ecx			;空きページ数 - 要求ページ数
	jb	.no_free_memory		;小さければメモリ不足

	mov	edx,[free_RAM_padr]	;空き物理メモリ
	shl	ebx,12			;ページテーブル用に必要なメモリ(byte)
	add	edx,ebx			;割りつける物理メモリをずらす
	call	set_physical_mem	;メモリ割り当て
	jc	.no_free_memory		;メモリ不足エラー

	sub	[free_RAM_pages],ecx	;空きメモリページ数減算
	shl	ecx,12			;byte 単位へ
	add	[free_RAM_padr] ,ecx	;空き物理メモリをずらす

	add	esi, ecx		;新しい最後尾アドレス
	mov	eax, [free_liner_adr]	;空きアドレス
	cmp	eax, esi
	ja	.step

	add	esi, LADR_ROOM_size + (LADR_UNIT -1)	;端数切上げ
	and	esi, 0ffc00000h				;下位 20ビット切捨て (4MB の倍数に)
	add	[free_liner_adr], esi			;空きアドレス更新

.step:
.no_alloc:
	clc		;キャリークリア
.exit:
	pop	edx
	pop	ecx
	pop	ebx
	pop	eax
	ret

	;ページテーブル作成のためのメモリが不足
.no_free_memory:
	stc
	jmp	short .exit


;------------------------------------------------------------------------------
;●テーブルを読み出し、物理メモリを配置しセレクタを作成する
;------------------------------------------------------------------------------
;引数	ds:ebx メモリマッピングテーブル
;
	align	4
map_memory:
	mov	eax,[ebx]		;作成するメモリセレクタ
	test	eax,eax			;値 check
	jz	.exit			;0 なら終了

	mov	edx,[ebx + 04h]		;edx = 張りつける物理アドレス
	mov	ecx,[ebx + 08h]		;ecx = 張りつけるページ数 -1
	mov	esi,edx			;esi = 張りつけ先リニアアドレス
	inc	ecx			;+1 する
	call	set_physical_mem	;物理メモリの配置

	lea	edi,[ebx + 4]		;セレクタ作成構造体
	call	make_selector_4k		;eax=作成するセレクタ  edi=構造体

	add	ebx,byte 10h		;アドレス更新
	jmp	short map_memory	;ループ

.exit:	ret


;------------------------------------------------------------------------------
;●セレクタのエイリアスを作成する
;------------------------------------------------------------------------------
;引数	ds:esi	エイリアステーブル
;
	align	4
make_aliases:
	;esi = エイリアステーブル
	mov	ebx,[esi  ]		;コピー元  セレクタ値
	mov	ecx,[esi+4]		;コピーするセレクタ値
	mov	eax,[esi+8]		;seg type
	test	ebx,ebx			;値確認
	jz	.ret
	call	make_alias		;別名作成

	add	esi,byte 0ch		;アドレス更新
	jmp	short make_aliases	;ループ
.ret:	ret


	align	4
make_alias:
	;-----------------------------------------------------
	;●エイリアス作成  ebx -> ecx, ah=type, al=level
	;-----------------------------------------------------
	push	eax
	mov	eax,ebx			;eax = セレクタ値
	call	sel2adr			;Ret ebx:アドレス
	mov	edx,ebx			;edx : コピー元アドレス
	mov	eax,ecx			;eax
	call	sel2adr			;ebx : コピー先アドレス

	;edx -> ebx
	mov	eax,[edx  ]		;コピー元
	mov	[ebx  ],eax		;コピー先

	pop	eax
	;ah=type, al=level

	mov	ecx,[edx+4]		;コピー元
	and	ch,90h			;bit 7,4 のみ取り出す
	shl	al,5			;level bit 6-5
	or	ch,al			;level の値を混ぜる
	or	ch,ah			;type の値を混ぜる
	mov	[ebx+4],ecx		;
	ret


;==============================================================================
;●サブルーチン
;==============================================================================
;------------------------------------------------------------------------------
;・最大割り当て可能メモリ量取得
;------------------------------------------------------------------------------
;Ret	eax = 最大割り当て可能メモリページ数
;
	align	4
get_maxalloc:
	push	ecx

	mov	eax, [free_RAM_pages]	;残り物理ページ数ロード
	mov	ecx, eax		;
	add	ecx, 000003ffh		;繰り上げ処理をして 1024 で除算
	shr	ecx, 10			;ecx = ページテーブルに必要なページ数
	sub	eax,ecx			;残りページ数 - ページテーブル用メモリ

	pop	ecx
	ret

;------------------------------------------------------------------------------
;・最大割り当て可能メモリ量取得
;------------------------------------------------------------------------------
;IN	esi = ベースアドレス
;Ret	eax = 最大割り当て可能メモリページ数
;	ebx = ページテーブル用に必要なページ数
;
	align	4
get_maxalloc_with_adr:
	push	ecx
	push	es
	push	d DOSMEM_sel
	pop	es

	mov	ebx, esi			;割りつけ先アドレス
	shr	ebx, 20				;bit 31-20
	and	 bl, 0fch			;bit 21,20 のクリア
	mov	eax, [es:page_dir_ladr+ebx]	;割り付け先頭のページテーブルを確認

	xor	ebx, ebx
	test	eax, eax
	jz	.step			;存在しないときは jump

	;
	mov	eax, esi		;割り付け先リニアアドレス
	shr	eax, 12
	and	eax, 03ffh		;使用済、ページエントリ数
	mov	ecx, 0400h ;=1024	;1テーブルの最大ペーシエントリ数
	sub	ecx, eax		;ecx = ページテーブ割当済、ページエントリ数

.step:
	mov	eax, [free_RAM_pages]	;残り物理ページ数ロード
	mov	ebx, eax		;
	sub	ebx, ecx		;ページテーブルの要らないエントリ数を引く
	add	ebx, 000003ffh		;繰り上げ処理をして 1024 で除算
	shr	ebx, 10			;ecx = ページテーブル用に必要なページ数
	sub	eax, ebx		;残りページ数 - ページテーブル用メモリ

	pop	es
	pop	ecx
	ret


;------------------------------------------------------------------------------
;・指定セレクタの最後尾リニアアドレス取得
;------------------------------------------------------------------------------
;IN	eax = セレクタ
;Ret	eax = セレクタ最後尾のリニアアドレス
;
	align	4
get_selector_last:
	push	ebx
	push	ecx
	push	edx

	mov	edx,eax		;セレクタ値保存
	call	sel2adr		;ディスクリプタアドレスに変換 ->ebx

	mov	ecx,[ebx+4]  	;bit 31-24
	mov	eax,[ebx+2]	;bit 23-0
	and	ecx,0ff000000h	;マスク
	and	eax, 00ffffffh	;
	or	eax,ecx		;値合成

	lsl	ecx,edx		;ecx = リミット値
	inc	ecx		;ecx = サイズ
	add	eax,ecx		;eax = セレクタ最後尾リニアアドレス

	pop	edx
	pop	ecx
	pop	ebx
	ret


;------------------------------------------------------------------------------
;・セレクタ値→ディスクリプタのアドレス変換
;------------------------------------------------------------------------------
;	IN	eax = セレクタ値
;	Ret	ebx = アドレス。セレクタ不正時は ebx=0
;		eax 以外は値保存
;
	align	4
sel2adr:
	mov	ebx,[cs:GDT_adr]	;GDT へのポインタ
	test	eax,4		 	;セレクタ値の bit 2 ?
	jz	short .GDT	 	; if 0 jmp

	mov	ebx,[cs:LDT_adr] 	;LDT へのポインタ
	cmp	eax,LDTsize
	ja	short .fail
	jmp	.success
.GDT:
	cmp	eax,GDTsize
	ja	short .fail
.success:
	and	al,0f8h			;bit 2-0 クリア
	add	ebx,eax			;加算
	ret
.fail:
	xor	ebx,ebx
	ret

;------------------------------------------------------------------------------
;・LDT内の空きセレクタ検索
;------------------------------------------------------------------------------
;	IN	(ds = F386_ds であること)
;	Ret	eax = 空きセレクタ (Cy=0)
;		    = 0 失敗       (Cy=1)
;
	align	4
search_free_LDTsel:
	push	ebx
	push	ecx

	mov	eax,LDT_sel	;LDT のセレクタ値
	lsl	ecx,eax		;ecx = LDT サイズ
	mov	eax,[LDT_adr] 	;LDT のアドレス
	add	ecx,[LDT_adr] 	;LDT 終了アドレス
	add	eax,byte 4	;+4

	align	4
.loop:	add	eax,byte 8	;アドレス更新
	cmp	eax,ecx		;サイズと比較
	ja	.no_desc	;サイズオーバ = ディスクリプタ不足
	test	b [eax+1],80h	;P ビット(存在ビット)
	jz	.found		;0 なら空きディスクリプタ
	jmp	short .loop

	align	4
.found:
	sub	eax,[LDT_adr] 	;LDTアドレス先頭を引く
	pop	ecx		;eax = 空きセレクタ
	pop	ebx
	clc
	ret


	align	4
.no_desc:
	xor	eax,eax		;eax =0
	pop	ecx
	pop	ebx
	stc
	ret

;------------------------------------------------------------------------------
;・全てのデータセレクタのリロード
;------------------------------------------------------------------------------
	align	4
selector_reload:
	push	ds
	push	es
	push	fs
	push	gs
	push	ss

	pop	ss
	pop	gs
	pop	fs
	pop	es
	pop	ds
	ret

;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
