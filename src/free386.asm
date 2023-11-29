;******************************************************************************
;　Free386 (compatible to RUN386 DOS-Extender)
;		'ABK project' all right reserved. Copyright (C)nabe@abk
;******************************************************************************
;[TAB=8]
;
%include	"nasm_abk.h"		;NASM 用ヘッダファイル
%include	"macro.asm"		;マクロ部の挿入
%include	"f386def.inc"		;定数部の挿入

%include	"start.inc"		;ファイル先頭 / 動作定義変数
%include	"sub.inc"		;便利なサブルーチンのヘッダファイル
%include	"f386sub.inc"		;Free386用 サブルーチン
%include	"f386seg.inc"		;セグメントライブラリ
%include	"f386cv86.inc"		;V86 ←→ Protect 低レベル連携ルーチン
%include	"int.inc"		;割り込みルーチンのヘッダファイル

;******************************************************************************
; global symbols
;******************************************************************************

	;--- for f386seg.asm ------------------------------
public		GDT_adr, LDT_adr
public		free_TABLE_ladr
public		free_LINER_ADR
public		free_RAM_padr
public		free_RAM_pages
public		DOS_mem_adr
public		DOS_mem_pages
public		page_dir

	;--- for f386cv86.asm -----------------------------
public		to_PM_EIP, to_PM_data_ladr
public		VCPI_entry
public		v86_cs
public		int_buf_adr, int_buf_adr_org
public		int_rwbuf_adr, int_rwbuf_adr_org
public		int_rwbuf_size
public		int_rwbuf_adr
public		VCPI_stack_adr
public		heap_malloc, stack_malloc
public		f386err

	;--- for int.asm ----------------------------------
public		work_adr
public		PM_stack_adr
public		END_program
public		IDT_adr
public		RVects_flag_tbl
public		DTA_off, DTA_seg
public		DOS_int21h_adr
public		top_adr
public		default_API
public		pharlap_version

public		callbuf_adr16
public		callbuf_seg16
public		callbuf_adr32

;******************************************************************************
;■コード(16 bit)
;******************************************************************************
segment	text public align=16 class=CODE use16
;------------------------------------------------------------------------------
;●初期処理
;------------------------------------------------------------------------------
	global	start
start:
	mov	ax,cs
	mov	bx,ds
	cmp	ax,bx		;cs と ds を比較
	je	.step		;等しければ（.com ﾌｧｲﾙ）処理継続

	mov		ds,ax		; ds を cs からロード
	PRINT86		EXE_err		;「com 形式で実行してください」
	Program_end	F386ERR		; プログラム終了(ret = 99)

	align	4
.step:	;///////////////////////////////
	;未使用 DOS メモリの開放
	mov	bx,1000h		;64KB / 16
	mov	ah,4ah			;メモリブロックサイズの変更
	int	21h			;DOS call

	call	get_parameter		;パラメタ解析(sub.inc)

;------------------------------------------------------------------------------
;●パラメタ確認 (free386 への動作指定)
;------------------------------------------------------------------------------
parameter_check:
	jmp	short .check_start

	;///////////////////////////////
	; -m : Use memory maximum
	;///////////////////////////////
.para_m:
	mov	b [pool_for_paging],1	;ページング用プールメモリ
	mov	b [real_mem_pages] ,250	;DOSメモリを最大まで使う, 255指定不可
	mov	b [maximum_heap]   ,1	;ヘッダを無視して最大ヒープメモリを割り当て
	jmp	.loop
	;/// Move some parameters to this location. Because does not fit in jmp short.
	;/// jmp short に収まらないので一部解析をここに記述

.check_start:
	mov	cx,[paras]		;パラメータ数
	test	cx,cx			;値確認
	jz	.end_paras		;0 ならば jmp

	inc	cx			;ループの関係上
	mov	bx,offset paras_p	;dx = argv / パラメータへのポインタ
.loop:
	dec	cx
	jz	.end_paras

	mov	si,[bx]			;si = argv[N] / パラメータへのポインタ
	add	bx,byte 2		;argv++ / ポインタ加算
	mov	ax,[si]			;先頭2文字ロード
	cmp	al,'-'			;'-' で始まるパラメタ?
	jne	.end_paras		;違ったらjmp (ロードファイル名と見なす)

	mov	al,[si+2]		;ah's next char

	cmp	ah,'v'
	je	.para_v
	cmp	ah,'q'
	je	.para_q
	cmp	ah,'p'
	je	.para_p
	cmp	ah,'c'
	je	.para_c
	cmp	ah,'m'
	je	.para_m
	cmp	ah,'2'
	je	.para_2
%if TOWNS
	cmp	ah,'n'
	je	.para_n
%endif
	cmp	ah,'i'
	je	.para_i
	jmp	short .loop

	;///////////////////////////////
	; -v
	;///////////////////////////////
.para_v:
	cmp	al,'v'			; -vv?
	je	.v0
	mov	al,01
.v0:
	mov	b [verbose],al
	jmp	short .loop

	;///////////////////////////////
	; -q
	;///////////////////////////////
.para_q:
	mov	b [title_disp],0	;no title output
	jmp	short .loop

	;///////////////////////////////
	; -p?
	;///////////////////////////////
.para_p:
	and	al,01			;-p? / al = ?
	mov	[see_PATH],al		;search PATH flag
	jmp	short .loop

	;///////////////////////////////
	; -c?
	;///////////////////////////////
.para_c:
	test	al,al			;-c? / al = ?
	jnz	.c0			
	mov	al,01			;指定なしなら -c1 と解釈
.c0:	and	al,03			;bit 1,0 取り出し
	mov	[reset_CRTC],al
	jmp	short .loop

	;///////////////////////////////
	; set PharLap version to 2.2 (compatible EXE386)
	;///////////////////////////////
.para_2:
	mov	d [pharlap_version], 20643232h	; ' d22'
	jmp	short .loop

%if TOWNS
	;///////////////////////////////
	; -n, do not load CoCo/NSD
	;///////////////////////////////
.para_n:
	and	al,01h			;al = -n?
	mov	b [nsdd_load],al
	jmp	short .loop
%endif

	;///////////////////////////////
	; -i?
	;///////////////////////////////
.para_i:
	and	al,01			;-i? / al = ?
	mov	b [check_MACHINE],al
	jmp	short .loop

.end_paras:

;------------------------------------------------------------------------------
;●タイトル表示
;------------------------------------------------------------------------------
	mov	al,[title_disp]	;タイトル表示する?
	test	al,al		;値 check
	jz	.no_title	;0 なら表示せず
	PRINT86	P_title		;タイトル表示
.no_title:


;------------------------------------------------------------------------------
;●簡易機種判別
;------------------------------------------------------------------------------
%if (MACHINE_CODE != 0)		;機種汎用でない

machine_check:
	mov	al,[check_MACHINE]	;機種判別フラグ
	test	al,al			;値確認
	jz	.no_check		;0 ならチェックしない

%if TOWNS
	call	check_TOWNS		;TOWNSか判別
%elif PC_98
	call	check_PC98		;PC-98x1か判別
%elif PC_AT
	call	check_AT		;PC/AT互換機か判別
%endif

	jnc	.check_safe		;Cy=0 なら該当機種
	PRINT86		err_10		;機種判別失敗
	Program_end	F386ERR		;終了

.no_check:
.check_safe:
%endif

;------------------------------------------------------------------------------
;●VCPI の存在確認
;------------------------------------------------------------------------------
	;
	;----- EMSの存在確認 -----
	;
%if Check_EMS
check_ems_driver:
	mov	ax,3567h	;int 67h のベクタ取得
	int	21h		;es:[bx] = ベクタ位置
	mov	bx,000ah	;ドライバ確認用文字列開始位置 'EMMXXXX0'

	mov	ax,[es:bx  ]	;前半の4文字確認
	mov	dx,[es:bx+2]	;
	cmp	ax,'EM'
	jne	short .not_found
	cmp	dx,'MX'
	jne	short .not_found

	mov	ax,[es:bx+4]	;後半4文字
	mov	dx,[es:bx+6]	;
	cmp	ax,'XX'
	jne	short .not_found
	cmp	dx,'X0'
	je	short .skip

	align	2
	;/// エラー処理 /////////
.not_found:
	PRINT86		err_01e		; 'EMS not found'
	Program_end	F386ERR		; 終了

.skip:
	push	ds
	pop	es
%endif

	;
	;----- VCPI の存在確認 -----
	;
VCPI_check:
	mov	ax,0de00h	; AL=00 : VCPI check!
	int	67h		; VCPI call
	test	ah,ah		; 戻り値 check
	jz	short .skip	; found VCPI

	PRINT86		err_01		; 'VCPI not find'
	Program_end	F386ERR		; 終了
.skip:
	
;------------------------------------------------------------------------------
;●ページディレクトリのメモリ確保
;------------------------------------------------------------------------------
	;///////////////////////////////////////////////////
	;ページディレクトリ用アドレス算出
	;///////////////////////////////////////////////////
	xor	ebx,ebx			;上位16ビットクリア
	xor	edx,edx			;

	mov	ax,offset end_adr	;プログラム最後尾オフセット
	mov	bx,ds			;データセグメント
	mov	dx,bx			;同じ
	add	ax,0fh			;端数切上げ
	shr	ax,4			;byte単位 -> para単位
	add	bx,ax			;終了リニア para アドレス
	add	bx,0ffh			;4KB 以下切上げ
	and	bx,0ff00h		;para 単位のリニアアドレス

	mov	bp,bx			;リニアアドレス(/16)をコピー
	sub	bx,dx			;セグメント値を引く
	shl	bx,4			;オフセットに変換
	mov	[page_dir],bx		;ページディレクトリ先頭オフセット
	mov	ax,bx
	add	ax,1000h		;+4KB
	mov	[page_table0],ax	;ページテーブル0の先頭オフセット

	; 8KB zero fill
	xor	eax,eax			;eax = 0
	mov	edi,ebx			;書き込み先  es:edi
	mov	ecx,2000h / 4		;書き込み回数
	rep	stosd			;ページテーブルメモリを 0 クリア

	shl	edx,4			;このプログラムの先頭リニアアドレス
	mov	[top_adr],edx		;記憶

	mov	cx,bp			;page dir リニアアドレス(/16)
	shr	cx,(12-4)		;para単位 -> page単位
	mov	ax,0de06h		;VCPI 06h/物理アドレス取得
	int	67h			;物理アドレス取得 -> edx
	mov	[to_PM_CR3],edx		;CR3 の値として記録

	;///////////////////////////////////////////////////
	;ページディレクトリ初期化
	;///////////////////////////////////////////////////
	add	cx,1			;4KB 先が最初のページtable
	mov	ax,0de06h		;VCPI 06h/物理アドレス取得
	int	67h			;VCPI call
	mov	dl,07h			;有効なtableエントリへ
	mov	[bx],edx		;最初のページテーブルをエントリする

;------------------------------------------------------------------------------
;●メモリ管理情報の設定
;------------------------------------------------------------------------------
	;メモリ管理情報の設定：断片メモリと、空き最上位メモリを算出する

	;ページディレクトリやページテーブルは 4KB に align されなければならず、
	;プログラム終端との間に空きメモリ領域が発生してしまう。 >frag_mem

	mov	ax,[page_dir]		;page ディレクトリオフセット
	mov	dx,ax			;dx にもセーブ
	sub	ax,offset end_adr	;ax = 使われてないメモリ領域
	add	dx,2000h		;空き最上位メモリ
	mov	[frag_mem_size ],ax	;値をセーブ
	mov	[top_mem_offset],dx	;

	;*** これで malloc などが使用可能になる ***

;------------------------------------------------------------------------------
;●メモリ総量の取得 / VCPI
;------------------------------------------------------------------------------
get_vcip_memory_size:
	mov	ax,0de02h			;VCPI function 02h
	int	67h				;最上位ページの物理アドレス
	shr	edx,12				;アドレス -> page
	inc	edx				;edx = 総メモリページ数

	mov	eax, Memory_page_max		;最大メモリ量制限
	cmp	edx, eax
	jb	short .step
	mov	edx, eax
.step:
	mov	[all_mem_pages],edx		;値記録

;------------------------------------------------------------------------------
;●alloc DOS memory - for call buffer / work address
;------------------------------------------------------------------------------
alloc_call_buffer:
	xor	bh, bh
	mov	bl, [callbuf_sizeKB]	;CALL Buffer size (KB)
	test	bl, bl
	jnz	short .step
	mov	bl, 1			;最低1KBは確保
	mov	[callbuf_sizeKB], bl
.step:
	xor	eax, eax
	shl	bx, 10-4 		; KB to para
	mov	ah, 48h
	int	21h
	jnc	.alloc		;成功なら jmp

	PRINT86		err_11		; CALL buffer確保失敗
	Program_end	F386ERR		; 終了

.alloc:
	mov	[callbuf_seg16], ax	; real segment
	shl	eax, 4
	mov	[callbuf_adr32],eax	; liner address

	;//////////////////////////////////////////////////
	;汎用ワーク領域
	;//////////////////////////////////////////////////
	mov	ax,WORK_SIZE		;汎用ワークサイズ
	call	heap_malloc		;上位メモリ割り当て
	mov	[work_adr],di		;記録

;------------------------------------------------------------------------------
;●機種固有の初期化設定（メモリ設定済後）
;------------------------------------------------------------------------------

%if TOWNS
	call	init_TOWNS
%elif PC_98
	;call	init_PC98
%elif PC_AT
	;call	init_AT
%endif

;------------------------------------------------------------------------------
;●スタックメモリの確保と設定
;------------------------------------------------------------------------------
	mov	ax,V86_stack_size	;V86時 stack
	call	stack_malloc		;下位メモリ割り当て
	mov	sp,di			;スタック切替え

	mov	[v86_cs],cs		;cs 退避
	mov	[v86_sp],di		;sp 退避

	mov	ax,PM_stack_size	;プロテクトモード時 stack
	call	stack_malloc		;下位メモリ割り当て
	mov	[PM_stack_adr],di	;記録

	mov	ax,VCPI_stack_size	;CPU Prot->V86 切り換え時専用 stack
	call	stack_malloc		;下位メモリ割り当て
	mov	[VCPI_stack_adr],di	;記録

;------------------------------------------------------------------------------
;●その他のメモリの確保と設定
;------------------------------------------------------------------------------
	xor	edi,edi			;上位 16 bit クリア

	;//////////////////////////////////////////////////
	;リアルモードベクタ保存領域
	mov	ax,Real_Vectors *4	;INT の数
	call	heap_malloc		;上位メモリ割り当て
	mov	[RVects_save_adr],di	;記録

	;リアルモードベクタの保存
	push	ds
	xor	esi,esi			;転送元
	mov	 ds,si			;ds = 0
	mov	ecx,Real_Vectors	;転送回数 = ベクタ数
	rep	movsd			;一括転送  ds:esi -> es:edi
	pop	ds

	;//////////////////////////////////////////////////
	;GDT/LDT/TSS
	mov	ax,GDTsize		;Global Descriptor Table's size
	call	heap_calloc		;上位メモリ割り当て
	mov	[GDT_adr],di		;記録

	mov	ax,LDTsize		;Local Descriptor Table's size
	call	heap_calloc		;上位メモリ割り当て
	mov	[LDT_adr],di		;記録

	mov	ax,IDTsize		;Interrupt Descriptor Table's size
	call	heap_calloc		;上位メモリ割り当て
	mov	[IDT_adr],di		;記録

	mov	ax,TSSsize		;Task State Segment's size
	call	heap_calloc		;上位メモリ割り当て
	mov	[TSS_adr],di		;記録

	;//////////////////////////////////////////////////
	;V86←→Protect連携ルーチンのセットアップ

	call	setup_cv86		;in f386cv86.asm

	;//////////////////////////////////////////////////
	;プロテクトモード←→V86 仲介バッファ
	mov	ax,INT_BUF_size * ISTK_nest_max	;バッファサイズ
	call	heap_malloc			;上位メモリ割り当て
	mov	[int_buf_adr],di		;記録
	mov	[int_buf_adr_org],di

	mov	ax,INT_RWBUF_size		;ファイル入出力専用
	mov	[int_rwbuf_size],ax
	call	heap_malloc			;上位メモリ割り当て
	mov	[int_rwbuf_adr],di		;記録
	mov	[int_rwbuf_adr_org],di


;------------------------------------------------------------------------------
;●XMS の確認と呼び出しアドレスの取得
;------------------------------------------------------------------------------
XMS_setup:
	mov	ax,4300h	;AH=43h : XMS
	int	2fh		;2fh call
	cmp	al,80h		;XMS install?
	je	.found		;等しければ jmp

	PRINT86		err_04		;「XMS が見つからない」
	Program_end	F386ERR		; 終了

	align	2
.found:
	push	es
	mov	ax,4310h		;XMS エントリポイントの取得
	int	2fh			
	mov	[XMS_entry  ],bx	;OFF
	mov	[XMS_entry+2],es	;SEG
	pop	es

	;/////////////////////////////
	;バージョン番号の取得
	xor	ah,ah		;ah = 0
	XMS_function		;XMS call
	mov	[XMS_Ver],ah	;Driver 仕様のメジャーバージョンを記録

	cmp	ah,3		;XMS 3.0?
	mov	al,[verbose]	;冗長表示フラグ
	je	get_EMB_XMS30	;等しければ jmp


;------------------------------------------------------------------------------
;●拡張メモリの確保 (use XMS2.0) / Max 64MB
;------------------------------------------------------------------------------
get_EMB_XMS20:
%if USE_XMS20
	test	al,al		;冗長な表示?
	jz	.step		;0 なら jmp
	PRINT86	msg_06		;「XMS2.0 発見」

.step:
	mov	ah,08h		;EMB 空きメモリ問い合わせ
	XMS_function		;XMS call
	test	ax,ax		;ax の値確認
	jz	get_EMB_failed	;0 なら失敗 (jmp)

	mov	[total_EMB_free],ax	;最大長、空きメモリサイズ (KB)
	mov	[max_EMB_free]  ,dx	;総空きメモリサイズ (KB)

	mov	dx,ax			;edx = 確保するメモリサイズ
	mov	ah,09h			;最大連続空きメモリを全て確保
	XMS_function			;確保
	test	ax,ax			;ax = 0?
	jz	get_EMB_failed		;0 なら確保失敗
	mov	[EMB_handle],dx		;EMBハンドルをセーブ

	jmp	lock_EMB	;確保したメモリのロック


	align	4
	;///////////////////////
	;メモリ確保失敗
	;///////////////////////
%endif
get_EMB_failed:
	PRINT86		err_05
	Program_end	F386ERR		; 終了


;------------------------------------------------------------------------------
;●拡張メモリの確保 (use XMS3.0)
;------------------------------------------------------------------------------
get_EMB_XMS30:
	test	al,al		;冗長な表示?
	jz	.step		;0 なら jmp
	PRINT86	msg_07		;「XMS3.0 発見」

.step:
	mov	ah,88h		;EMB 空きメモリ問い合わせ
	XMS_function		;XMS call
	test	bl,bl		;bl の値確認
	jnz	get_EMB_failed	;non 0 なら jmp

	mov	[max_EMB_free]  ,eax	;最大長、空きメモリサイズ (KB)
	mov	[total_EMB_free],edx	;総空きメモリサイズ (KB)
	mov	[EMB_top_adr ]  ,ecx	;管理する最上位アドレス

	mov	edx,eax			;edx = 確保するメモリサイズ
	mov	ah,89h			;最大連続空きメモリを全て確保
	XMS_function			;確保
	test	ax,ax			;ax = 0?
	jz	get_EMB_failed		;0 なら確保失敗
	mov	[EMB_handle],dx		;EMBハンドルをセーブ
	jmp	short lock_EMB		;EMBのロック


;------------------------------------------------------------------------------
;●確保した拡張メモリのロック と 拡張メモリの初期情報設定
;------------------------------------------------------------------------------
	align	4
lock_failed:
	call	free_EMB	;EMB の開放
	PRINT86	err_07		;「ロック失敗」
	Program_END F386ERR	;プログラム終了

	align	4
lock_EMB:
	mov	ah,0ch		;EMB のロック
	XMS_function		;
	test	ax,ax		;ax = 0?
	jz	lock_failed	;0 ならロック失敗

	;
	;DX:BX = メモリブロック先頭物理アドレス
	;
	shl	edx,16		;上位へ
	mov	 dx,bx		;edx = 先頭物理アドレス
	mov	eax,edx		;eax に copy

	add	edx,     0fffh		;端数切り上げ
	and	edx,0fffff000h		;bit 11-0 のクリア
	mov	[EMB_physi_adr],edx	;実際に使用する先頭物理アドレス

	mov	ecx,[max_EMB_free]	;確保されたメモリサイズ (KB)
	sub	edx,eax			;利用開始アドレス - 確保したアドレス
	jz	short .jp
	dec	ecx
.jp:	shr	ecx,2			;KB単位 → page 単位
	cmp	ecx,0x40000		;256Kpage max
	jb	.jp2
	mov	ecx,0x40000		;1GB max
.jp2:	mov	[EMB_pages],ecx		;使用可能なページ数として記録

;------------------------------------------------------------------------------
;alloc DOS memory - for page table
;------------------------------------------------------------------------------
alloc_page_table:
	mov	ebx, [EMB_physi_adr]	; free Phisical address
	shr	ebx, 22			; to need page tables
	jz	.skip

	mov	bp, bx			; need tables save to bp

	xor	eax, eax
	inc	ebx			; for fragment
	shl	ebx, 12 - 4 		; PAGE to para
	mov	ah, 48h
	int	21h
	jnc	.alloc			; jump if success

	call		free_EMB
	PRINT86		err_12
	Program_end	F386ERR

.alloc:
	shl	eax, 4
	mov	[page_table_in_dos_memory_adr] ,eax	; liner address
	shl	ebx, 4
	mov	[page_table_in_dos_memory_size],ebx	; size

	; prepare loop
	add	eax, 0fffh		; for align 4KB
	shr	eax, 12
	mov	cx, ax
	mov	bx, [page_dir]
.loop:
	mov	ax,0de06h		; get Phisical address
	int	67h			; VCPI call
	mov	dl,07h			; address to table entry
	add	bx, 4
	mov	[bx], edx		; entry to page directory

	; clear page table
	push	cx
	shl	cx, 12-4		; PAGE to para
	mov	es, cx
	xor	di, di
	mov	cx, 1000h / 4		; 4KB/4
	xor	eax, eax
	rep	stosd
	pop	cx

	inc	cx			; for loop
	dec	bp
	jnz	.loop

	push	ds
	pop	es
.skip:

;------------------------------------------------------------------------------
;●DOS memory for exp
;------------------------------------------------------------------------------
alloc_real_mem_for_exp:
	xor	eax, eax
	xor	bh, bh
	mov	bl, b [real_mem_pages]	;CALL Buffer size (page)
	mov	cl, bl
	inc	bl			;4KB境界調整用に1つ多く確保
	shl	bx, 8			;Page to para(Byte/16)

	mov	ah,48h
	int	21h
	jnc	.success

	cmp	ax,08h
	jnz	.fail

	;原因はメモリ不足, bx=最大メモリ
	and	bx, 0ff00h		;4KB単位に
	mov	cx, bx
	shr	cx, 8			;para to page
	dec	cl

	;再度割り当て実行
	mov	ah,48h
	int	21h
	jc	.fail

.success:
	shl	eax, 4			; para to offset
	add	eax, 0x00000fff
	and	eax, 0xfffff000
	mov	[DOS_mem_adr], eax	; 4KB page top
	mov	[DOS_mem_pages], cl	
.fail:

;------------------------------------------------------------------------------
;●VCPI用セレクタの初期化
;------------------------------------------------------------------------------
	;///////////////////////////////////////////////////
	;VCPI 呼び出し  01h
	;///////////////////////////////////////////////////
	xor	edi,edi			;edi の上位16bit クリア
	mov	si,[GDT_adr]		;GDT へのオフセットロード
	add	si,VCPI_sel		;VCPI のセグメント配置アドレスへ
	mov	di,[page_table0]	;ページテーブル0 先頭オフセット保存
	mov	ax,0de01h		;
	int	67h			;VCPI Function

	test	ah,ah			;戻り値 check
	jz	save_VCPI_statas	;問題なければ jmp

	call		free_EMB	; 拡張メモリの開放
	PRINT86		err_02		; 'VCPI not find'
	Program_end	F386ERR		; 終了

	align	4
save_VCPI_statas:
	mov	[VCPI_entry],ebx	;VCPI サービスエントリ
	sub	 di,[page_table0]	;ユーザ用offset - 先頭offset
	shl	edi,(12-2)		;edi ユーザー用リニアアドレス開始位置
	mov	[free_LINER_ADR],edi	;未定義のリニアアドレス最低位番地


;------------------------------------------------------------------------------
;●DOS-Extender 環境の構築と変数の準備（V86 側）
;------------------------------------------------------------------------------
	;///////////////////////////////////////////////////
	;DTA ディフォルトアドレス設定
	;///////////////////////////////////////////////////
	;mov	dx,[DTA_off]		;データ領域に記述してある offset
	;mov	ah,1ah			;DTA アドレス設定
	;int	21h

	;///////////////////////////////////////////////////
	;割り込みマスク保存
	;///////////////////////////////////////////////////
%if SAVE_8259A && enable_INTR
	in	al,I8259A_IMR_S		;8259A スレーブ
	mov	ah,al			;ah へ移動
	in	al,I8259A_IMR_M		;8259A マスタ
	mov	[intr_mask_org],ax	;記憶
%endif

	;///////////////////////////////////////////////////
	;int21h アドレス記憶
	;///////////////////////////////////////////////////
	xor	ax,ax			;ax = 0
	mov	gs,ax			;es = 0
	mov	eax,[gs:21h*4]		;DOS function CS:IP
	mov	[DOS_int21h_adr],eax	;記録


;------------------------------------------------------------------------------
;●ＣＰＵモード切替え準備
;------------------------------------------------------------------------------
	mov	eax,[top_adr]		;プログラム先頭リニアアドレス
	mov	ecx,[GDT_adr]		;GDT オフセット
	mov	edx,[IDT_adr]		;IDT オフセット
	add	ecx,eax			;リニアアドレス
	add	edx,eax			;
	mov	esi,offset LGDT_data	;ロード値を記録するリニアアドレス
	mov	edi,offset LIDT_data	;
	mov	[si+2],ecx		;ロード用データ領域に記録
	mov	[dI+2],edx		;
	add	esi,eax			;リニアアドレス算出
	add	edi,eax			;
	mov	[to_PM_GDTR],esi	;GDT へのロード値のあるリニアアドレス
	mov	[to_PM_IDTR],edi	;IDT へのロード値のあるリニアアドレス

	;mov	w [to_PM_LDTR],LDT_sel		;LDTRの値（初期値定義済）
	;mov	w [to_PM_TR]  ,TSS_sel		;TRの値（初期値定義済）
	mov	d [to_PM_EIP] ,offset start32	;EIP の値
	;mov	w [to_PM_CS]  ,F386_cs		;CS の値（初期値定義済）


;------------------------------------------------------------------------------
;●GDT 初期設定ルーチン
;------------------------------------------------------------------------------
;GDT 内の LDT / IDT / TSS / DOSメモリ セレクタの設定
;
	mov	 di,[GDT_adr]	;GDT のオフセット
	mov	ebx,[top_adr]	;このプログラムの先頭リニアアドレス(bit 31-0)

	;/// Free386用 CS/DS 設定 ///////////////////////////////////

	mov	dl,[top_adr +2]	;bit 16-23
	mov	ax,0ffffh	;リミット値

	mov	cl,40h			;386形式
	mov	dh,9ah			;R/X 386
	mov	[di + F386_cs    ],ax
	mov	[di + F386_cs  +2],bx
	mov	[di + F386_cs  +4],dx
	mov	[di + F386_cs  +6],cl

	mov	dh,92h			;R/W 386
	mov	[di + F386_ds    ],ax
	mov	[di + F386_ds  +2],bx
	mov	[di + F386_ds  +4],dx
	mov	[di + F386_ds  +6],cl

	mov	dh,9ah			;R/X 286
	mov	[di + F386_cs2   ],ax
	mov	[di + F386_cs2 +2],bx
	mov	[di + F386_cs2 +4],dx

	mov	dh,92h			;R/W 286
	mov	[di + F386_ds2   ],ax
	mov	[di + F386_ds2 +2],bx
	mov	[di + F386_ds2 +4],dx


	;/// LDT セレクタの設定 /////////////////////////////////////

	mov	ecx,[LDT_adr]			;LDT のオフセット
	add	ecx,ebx				;先頭アドレス加算
	mov	 ax,LDTsize -1			;LDT の大きさ -1

	mov	[di + LDT_sel + 2],ecx		;ベースアドレス設定
	mov	[di + LDT_RW  + 2],ecx		;
	mov	[di + LDT_sel],ax		;リミット値設定
	mov	[di + LDT_RW ],ax		;

	mov	w [di + LDT_sel + 5],0082h	;属性設定 (LDT)
	mov	w [di + LDT_RW  + 5],4092h	;属性設定 (Read/Write)

	;/// GDT/IDT アクセス用セレクタの設定 ///////////////////////

	mov	ecx,[GDT_adr]			;GDT オフセット
	mov	edx,[IDT_adr]			;IDT オフセット
	add	ecx,ebx				;先頭アドレス加算
	add	edx,ebx				;  〃
	mov	[di + GDT_RW + 2],ecx		;ベースアドレス設定
	mov	[di + IDT_RW + 2],edx		;  〃
	mov	w [di + GDT_RW],GDTsize-1	;リミット値設定
	mov	w [di + IDT_RW],IDTsize-1	;
	mov	w [di + GDT_RW +5],4092h	;属性設定 (Read/Write)
	mov	w [di + IDT_RW +5],4092h	;属性設定 (Read/Write)

	;/// TSS セレクタの設定 /////////////////////////////////////

	mov	ecx,[TSS_adr]			;TSS のオフセット
	add	ecx,ebx				;先頭アドレス加算
	mov	ax,TSSsize -1			;TSS の大きさ -1

	mov	[di + TSS_sel + 2],ecx		;ベースアドレス設定
	mov	[di + TSS_RW  + 2],ecx		;
	mov	[di + TSS_sel],ax		;リミット値設定
	mov	[di + TSS_RW ],ax		;

	mov	w [di + TSS_sel + 5],0089h	;属性設定 (利用可能/Avail TSS)
	mov	w [di + TSS_RW  + 5],4092h	;属性設定 (Read/Write)

	;/// DOSメモリ/全メモリアクセス用セレクタ ///////////////////
	mov	edx, [all_mem_pages]		;総メモリページ数

	;リミット値設定
	mov	w [di + DOSMEM_sel],(DOSMEMsize / 4096) -1
	mov	  [di + ALLMEM_sel],dx		;下位のみ設定

	shr	edx,8				;bit8-11 に リミット値bit16-19
	and	dx,00f00h			;属性部マスク
	or	dx,0c092h			;属性部を設定

	mov	w [di + DOSMEM_sel +5],0c092h	;属性設定 (利用可能/Avail TSS)
	mov	  [di + ALLMEM_sel +5],dx	;属性設定 (Read/Write)


	;////////////////////////////////////////////////////////////
	;/// 環境設定 IDT ///////////////////////////////////////////

	;;mov	w [offset IDT + int_ret_PM *8],offset ret_PM_handler
	;;mov	w [offset IDT + int_ret_PM2*8],offset ret_PM_handler2

	;/// 設定終了 ///////////////////////////////////////////////
	;////////////////////////////////////////////////////////////


;------------------------------------------------------------------------------
;●割り込みテーブル初期設定ルーチン
;------------------------------------------------------------------------------
;	dw	offset %1	;offset  bit 0-15
;	dw	F386_cs		;selctor
;	dw	0ee00h		;属性 (386割り込みゲート) / 特権レベル3
;	dw	00000h		;offset  bit 16-31
setup_IDT:
	mov	 ax,F386_cs	;セレクタ
	xor	edx,edx		;上位ビットクリア
	shl	eax,16		;上位へ
	mov	edx,0ee00h	;386割り込みゲート / 特権レベル3
	mov	di,[IDT_adr]	;割り込みテーブル先頭

	;/// CPU 内部割り込み設定 /////////////////////////
	mov	ax,offset PM_int_00h	;割り込み #00
	mov	cx,20h			;00h ～ 1fh
	mov	bp,8			;加算値
	call	write_IDT		;IDT へ書き込み

	;/// DOS割り込み設定 //////////////////////////////
	mov	cx,10h			;20h ～ 2fh
	mov	si,offset DOS_int_list	;DOS 割り込みリスト

	align	4
.loop1:	mov	ax,[si]			;jmp 先読み出し
	mov	[di  ],eax		;+00h
	mov	[di+4],edx		;+04h
	add	si,byte 4		;次の割り込みリスト項目
	add	di,bp			;セレクタオフセット更新
	loop	.loop1

	;/// ダミールーチンの配置 /////////////////////////
	mov	cx,100h - 30h		;30h ～ 0ffh
	mov	ax,offset PM_int_dummy	;ダミールーチン

	align	4
.loop2:	mov	[di  ],eax		;+00h
	mov	[di+4],edx		;+04h
	add	di,bp			;セレクタオフセット更新
	loop	.loop2


	;/// ハードウェア割り込み /////////////////////////
%if enable_INTR
	mov	ax,offset intr_M0	;割り込みマスタ側 #00
	mov	di,[IDT_adr]		;割り込みテーブル先頭
	mov	cx,8			;ループ数
	add	di,INTR_MASTER *8	;マスタ側割り込み番号 *8
	call	write_IDT		;IDT へ書き込み

	mov	ax,offset intr_S0	;割り込みスレーブ側 #00
	mov	di,[IDT_adr]		;割り込みテーブル先頭
	mov	cx,8			;ループ数
	add	di,INTR_SLAVE *8	;スレーブ側割り込み番号 *8
	call	write_IDT		;IDT へ書き込み
%endif

;------------------------------------------------------------------------------
;●ＣＰＵモード切替え
;------------------------------------------------------------------------------
	mov	ax,0de0ch		;VCPI function  0Ch
	mov	esi,[top_adr]		;プログラム先頭リニアアドレス
	add	esi,offset to_PM_data	;切替え用構造体アドレス
	mov	[to_PM_data_ladr],esi	;上記リニアアドレス記録

	int	67h			;プロテクトモードの start32 へ

	call		free_EMB	; 拡張メモリの開放
	PRINT86		err_03		; CPU 切替え失敗
	Program_end	F386ERR		; 終了


;==============================================================================
;■サブルーチン
;==============================================================================
;------------------------------------------------------------------------------
;●割り込みテーブルへの書き出し（from IDT 初期設定ルーチン）
;------------------------------------------------------------------------------
	align	4
write_IDT:
	mov	[di  ],eax		;+00h
	mov	[di+4],edx		;+04h
	add	ax,bp			;次の割り込みアドレスへ
	add	di,bp			;セレクタオフセット更新
	loop	write_IDT
	ret


;------------------------------------------------------------------------------
;●メモリアロケーション
;------------------------------------------------------------------------------
;	in	ax = size (byte)
;	out	di = offset
;
;多重メモリアロケーションの回避は考えていない。
;16 の倍数以外は指定しないことが望ましい。
;
	align	4
heap_malloc:		;上位からのメモリ割り当て
%if USE_frag_mem
	cmp	ax,[frag_mem_size]	;断片化メモリのサイズと比較
	ja	.not_frag_mem		;if ↑より大きい jmp

	mov	di,[frag_mem_offset]	;断片化メモリの割り当て
	sub	[frag_mem_size  ],ax	;割り当てたメモリ量を引く
	add	[frag_mem_offset],ax	;空きメモリを示すポインタを更新
	ret
%endif
	align	4
.not_frag_mem:		;上位空きメモリの単純な割り当て
	mov	di,[top_mem_offset]	;上位空きメモリ割り当て
	add	[top_mem_offset],ax	;サイズ分加算
	jmp	short check_heap_mem

	align	4
stack_malloc:		;下位からのメモリ割り当て
	mov	di,[down_mem_offset]	;最下位空きメモリ
	sub	[down_mem_offset],ax	;新たな値を記録
	; jmp	short check_heap_mem
check_heap_mem:
	push	ax
	push	bx
	mov	ax,[top_mem_offset]
	mov	bx,[down_mem_offset]
	dec	ax
	dec	bx
	cmp	ax,bx
	pop	bx
	pop	ax
	ja	.error
	ret
.error:
	mov	ah, 25h			;error code
	jmp	program_err_end


	;//////////////////////////////////////////////////
	;0 初期化したメモリの取得
	;//////////////////////////////////////////////////
	align	4
heap_calloc:
	push	w (mem_clear)		;戻りラベル
	jmp	heap_malloc

	align	4
stack_calloc:
	std
	push	w (mem_clear)		;戻りラベル
	jmp	stack_malloc

	align	4
mem_clear:		;メモリの 0 クリア
	push	eax
	push	ecx
	push	edi

	movzx	ecx,ax			;ecx メモリサイズ
	movzx	edi,di			;edi 書き込み先
	xor	eax,eax			;eax = 0
	shr	ecx,2			;4 で割る
	rep	stosd			;メモリ塗りつぶし ->es:[edi]

	pop	edi
	pop	ecx
	pop	eax
	cld
	ret


;------------------------------------------------------------------------------
;●確保した拡張メモリの開放
;------------------------------------------------------------------------------
	align	4
free_EMB:
	mov	dx,[EMB_handle]	;dx = EMBハンドル
	test	dx,dx		;ハンドルの値確認
	jz	.ret		;0 ならば ret

	mov	ah,0dh		;EMB のロック解除
	XMS_function

	mov	ah,0ah		;EMB の開放
	XMS_function
	test	ax,ax		;ax = 0 ?
	jnz	.ret		;non 0 なら jmp
	PRINT86	err_06		;「メモリ開放失敗」

.ret	ret


;##############################################################################
;==============================================================================
;■プログラムの終了 (16 bit)
;==============================================================================
	align	4
END_program16:
	;////////////////////////////////////////////////////////////
	;/// 割り込みマスク復元 /////////////////////////////////////
%if SAVE_8259A && enable_INTR
	mov	ax,[intr_mask_org]	;復元情報
	out	I8259A_IMR_M, al	;マスタ側
	mov	al,ah			;
	out	I8259A_IMR_S, al	;スレーブ側
%endif

%if TOWNS
	call	end_TOWNS16
%endif

	sti
	call	free_EMB		;確保したメモリの開放

	mov	ax,[err_level]		;AH = Free386 ERR / AL = Program ERR
	test	ah,ah			;check
	jnz	program_err_end		;non 0 ならエラー終了

	mov	ah,4ch
	int	21h			;正常終了


;------------------------------------------------------------------------------
;●内部エラー発生
;------------------------------------------------------------------------------
	align	4
program_err_end:
	sub	ah,20h			;内部エラーコード 00h～1fh は欠番
	movzx	si,ah			;si にエラー番号を
	add	si,si			;si*2
	mov	dx,[end_msg_table + si]	;エラーメッセージのアドレス

	mov	ah,09h			;メッセージ表示
	int	21h			;DOS call

	Program_end	F386ERR		; 終了


;******************************************************************************
;■コード(32 bit)
;******************************************************************************
BITS	32

%include	"f386prot.asm"		;プロテクトモード・メインプログラム

;------------------------------------------------------------------------------
;●プログラムの終了(32bit)
;------------------------------------------------------------------------------
	align	4
END_program:
	cli
	mov	bx,F386_ds		;ds 復元
	mov	ds,ebx			;
	mov	es,ebx			;VCPI で切り換え時、
	mov	fs,ebx			;セグメントレジスタは不定値
	mov	gs,ebx			;
	lss	esp,[PM_stack_adr]	;スタックポインタロード

	mov	[err_level],al		;エラーレベル記録

	;///////////////////////////////
	;各機種固有の終了処理
	;///////////////////////////////
%if TOWNS || PC_98 || PC_AT
	mov	al,[init_machine]
	test	al,al
	jz	.skip_machin_recovery

%if TOWNS
	call	end_TOWNS		;TOWNS の終了処理
%elif PC_98
	call	end_PC98		;PC-98x1 の終了処理
%elif PC_AT
	call	end_AT			;PC/AT互換機の終了処理
%endif

.skip_machin_recovery:
%endif
	;///////////////////////////////
	;リアルモードベクタの復元
	;///////////////////////////////
%if Rec_Real_Vec
Rec_vector:
	push	d (DOSMEM_sel)			;DOS メモリアクセスレジスタ
	pop	fs				;load
	mov	ecx,Real_Vectors		;ベクタ数
	mov	ebx,offset RVects_flag_tbl	;ベクタ書き換えフラグテーブル
	mov	esi,[RVects_save_adr]		;esi <- ベクタ保存領域

	align	4
.loop:
	dec	ecx			;ecx -1
	bt	[ebx],ecx		;書き換えをフラグ ?
	jc	.Recovary		;書き換えられてれば復元
	test	ecx,ecx			;カウンタ確認
	jz	.end
	jmp	short .loop

	align	4
.Recovary:
	mov	eax,[esi + ecx*4]	;オリジナル値ロード
	mov	[fs:ecx*4],eax		;復元

	test	ecx,ecx			;カウンタ確認
	jnz	.loop			;ループ

	align	4
.end:
%endif

	;///////////////////////////////
	;V86 モードへ戻る
	;///////////////////////////////
	mov	eax,[v86_cs]		;V86時 cs,ds
	mov	ebx,[v86_sp]		;V86時 sp

	cli				;割り込み禁止
	push	eax			;V86 gs
	push	eax			;V86 fs
	push	eax			;V86 ds
	push	eax			;V86 es
	push	eax			;V86 ss
	push	ebx			;V86 esp
	pushfd				;eflags
	push	eax			 ;V86 cs
	push	d (offset END_program16) ;V86 EIP / 終了ラベル

	mov	ax,0de0ch		;VCPI function 0ch / to V86 mode
	call    far [VCPI_entry]	;VCPI call


;******************************************************************************
;■機種依存コード
;******************************************************************************

%if TOWNS
	%include "towns.asm"
%endif

%if PC_98
	%include "pc98.asm"
%endif

%if PC_AT
	%include "at.asm"
%endif

;******************************************************************************
;■データ
;******************************************************************************

%include	"f386data.asm"		;データ部インクルード

;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
	align	16	;必須！！
end_adr:

;******************************************************************************
;******************************************************************************
