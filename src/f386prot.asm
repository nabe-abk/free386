;******************************************************************************
;　Free386	＜プロテクトモード処理部＞
;******************************************************************************
;
; 2001/01/18 ファイルを分離
;
;
;
BITS	32
;==============================================================================
;★プロテクトモード スタートラベル
;==============================================================================
	align	16
start32:
	mov	ebx,F386_ds		;ds セレクタ
	mov	ds,ebx			;ds ロード
	mov	es,ebx			;es
	mov	fs,ebx			;fs
	mov	gs,ebx			;gs
	lss	esp,[PM_stack_adr]	;スタックポインタロード

;------------------------------------------------------------------------------
;●割り込み設定
;------------------------------------------------------------------------------
	;///////////////////////////////
	;int 23h のフック
	;///////////////////////////////
	mov	eax,2506h		;常にプロテクトモードで発生する割り込み
	mov	 cl,23h			;CTRL-C 割り込み
	mov	edx,offset END_program	;hook 先ルーチン

	push	cs
	pop	ds			;ds:edx = エトリーアドレス
	int	21h			;DOS-Extender function

	mov	ds,ebx			;ds 復元

	;///////////////////////////////
	;Free386 独自割り込みの設定
	;///////////////////////////////
	call	setup_F386_int		;see int_f386.asm

%if (enable_INTR)
	sti			;割り込み許可
%endif

;------------------------------------------------------------------------------
; Memory detail infomation
;------------------------------------------------------------------------------
internal_mem_dump:
	mov	al, [verbose]
	cmp	al, 2
	jb	near .skip

	mov	edi, internal_mem_msg

	mov	eax, end_adr
	dec	eax
	call	rewrite_next_hash_to_hex

	mov	eax, [v86_cs]
	call	rewrite_next_hash_to_hex

	mov	eax, end_adr
	call	rewrite_next_hash_to_hex

	mov	eax, [page_dir]
	dec	eax
	call	rewrite_next_hash_to_hex

	mov	eax, [frag_mem_size]
	call	rewrite_next_hash_to_deg

	mov	eax, [page_dir]
	call	rewrite_next_hash_to_hex
	add	eax, 1fffh
	call	rewrite_next_hash_to_hex
	inc	eax
	call	rewrite_next_hash_to_hex

	mov	ebx, [top_mem_offset]
	mov	edx, [down_mem_offset]

	mov	eax, 10000h
	sub	eax, [page_dir]
	call	rewrite_next_hash_to_deg

	mov	eax, ebx
	call	rewrite_next_hash_to_hex
	mov	eax, edx
	dec	eax
	call	rewrite_next_hash_to_hex

	mov	eax, edx
	sub	eax, ebx
	call	rewrite_next_hash_to_deg

	; Real mode vectors backup
	mov	eax, [RVects_save_adr]
	call	rewrite_next_hash_to_hex
	add	eax,  IntVectors *4 -1
	call	rewrite_next_hash_to_hex

	; GDT/LDT/IDT/TSS
	mov	eax, [GDT_adr]
	call	rewrite_next_hash_to_hex
	add	eax, GDTsize -1
	call	rewrite_next_hash_to_hex

	mov	eax, [LDT_adr]
	call	rewrite_next_hash_to_hex
	add	eax, LDTsize -1
	call	rewrite_next_hash_to_hex

	mov	eax, [IDT_adr]
	call	rewrite_next_hash_to_hex
	add	eax, IDTsize -1
	call	rewrite_next_hash_to_hex

	mov	eax, [TSS_adr]
	call	rewrite_next_hash_to_hex
	add	eax, TSSsize -1
	call	rewrite_next_hash_to_hex

	; work memory
	mov	eax, [work_adr]
	call	rewrite_next_hash_to_hex
	add	eax,  WORK_size -1
	call	rewrite_next_hash_to_hex

	; stack info
	mov	eax, [VCPI_stack_adr]
	sub	eax,  VCPI_stack_size
	call	rewrite_next_hash_to_hex

	mov	eax, [PM_stack_adr]
	sub	eax,  PM_stack_size
	call	rewrite_next_hash_to_hex

	movzx	eax, w [v86_sp]
	sub	eax, V86_stack_size
	call	rewrite_next_hash_to_hex

	PRINT	internal_mem_msg
.skip:

;------------------------------------------------------------------------------
;●メモリ管理の設定
;------------------------------------------------------------------------------
make_page_tables:
	mov	al,[verbose]
	test	al,al
	jz	near .no_verbose

	mov	edi, msg_02

	;/// 総物理メモリ量 ///
	mov	eax,[all_mem_pages]	;メモリドライハによって実際とは違う値が返る
	shl	eax,2			;4倍して eax = XXX KB
	call	rewrite_next_hash_to_deg

	;/// 確保した拡張メモリ ///
	mov	eax,[max_EMB_free]
	call	rewrite_next_hash_to_deg
	mov	eax,[EMB_physi_adr]
	call	rewrite_next_hash_to_hex

	;/// リアルメモリ ///
	mov	eax,[DOS_mem_pages]	;
	shl	eax, 2			;page to KB
	call	rewrite_next_hash_to_deg
	mov	eax,[DOS_mem_adr]
	call	rewrite_next_hash_to_hex

	;/// call buffer ///
	movzx	eax,b [callbuf_sizeKB]
	call	rewrite_next_hash_to_deg
	mov	eax,[callbuf_adr32]
	call	rewrite_next_hash_to_hex

	;/// Additional page table memory ///
	mov	eax, [page_table_in_dos_memory_size]
	shr	eax, 10
	call	rewrite_next_hash_to_deg
	mov	eax,[page_table_in_dos_memory_adr]
	call	rewrite_next_hash_to_hex

	PRINT_	msg_02
.no_verbose:

	;--------------------------------------------------
	;メモリ管理情報の設定
	;--------------------------------------------------
	mov	eax,[EMB_pages]		;EMBメモリページ数
	mov	edx,[EMB_physi_adr]	;空き物理メモリ先頭
	mov	[free_RAM_pages] ,eax	;全プロテクトメモリとして使用する
	mov	[free_RAM_padr]  ,edx	;空き先頭物理メモリ先頭アドレス

	test	eax,eax			;プロテクトメモリ量
	jnz	.step			;0 でなければ継続(jmp)

	F386_end	21h		;メモリなし
.step:

;------------------------------------------------------------------------------
;●全メモリを示すセレクタを作成
;------------------------------------------------------------------------------
make_all_mem_sel:
	mov	ecx,[all_mem_pages]	;eax <- 総メモリページ数
	mov	edx,ecx
	mov	edi,[work_adr]		;ワークメモリ
	dec	edx			;edx = limit値 ( /pages)
	mov	d [edi  ],0		;
	mov	d [edi+4],edx		;
	mov	d [edi+8],0200h		;メモリタイプ / 特権レベル=0

	mov	eax,ALLMEM_sel		;全メモリアクセスセレクタ
	call	make_mems_4k		;メモリセレクタ作成 edi=構造体 eax=sel

	;
	;全メモリセレクタ作成後に以下は実行
	;
	;mov	ecx,[all_mem_pages]	;eax <- 総メモリページ数
	mov	esi,[free_LINER_ADR]	;空きリニアアドレス
	mov	edx,esi			;物理アドレスと1対1

	add	ecx,0xff		;255pages
	xor	 cl,cl			;1MB単位に切り上げ
	shl	ecx,12			;eax = 物理アドレス最大値
	mov	[free_LINER_ADR],ecx	;空きリニアアドレス更新
	sub	ecx,esi			;割り当てるメモリサイズ
	shr	ecx,12			;割り当てるページ数

	; esi = 張りつけ先リニアアドレス
	; edx = 張りつける物理アドレス
	; ecx = 張りつけるページ数
	call	set_physical_mem

;------------------------------------------------------------------------------
;●セレクタの作成（LDT内 セレクタ）
;------------------------------------------------------------------------------
	;-------------------------------
	;★PSPセレクタの作成
	;-------------------------------
	mov	edi,[work_adr]		;ワークアドレスロード
	mov	eax,[top_adr]		;プログラム先頭リニアアドレス
	mov	d [edi+4],256 -1	;limit
	mov	d [edi  ],eax		;base
	mov	d [edi+8],0200h		;R/W タイプ / 特権レベル=0
	mov	eax,PSP_sel1		;PSP セレクタ1
	call	make_mems		;メモリセレクタ作成 edi=構造体 eax=sel
	mov	eax,PSP_sel2		;PSP セレクタ2
	call	make_mems		;メモリセレクタ作成 edi=構造体 eax=sel

	;-------------------------------
	;★DOS環境変数セレクタの作成
	;-------------------------------
	xor	ebx,ebx
	mov	eax,DOSMEM_sel		;DOS メモリアクセスセレクタ
	mov	 fs,eax			;fs に代入

	mov	 bx,[2Ch]		;下位 2バイト = ENV のセグメント
	shl	ebx,4			;16 倍してリニアアドレスへ
	mov	 ax,[fs:ebx -16 + 3]	;PSP のサイズ / MCB を参照している
	shl	eax,4			;16 倍 para -> byte
	dec	eax			;size -> limit 値
	mov	d [edi  ],ebx		;base
	mov	d [edi+4],eax		;limit / 32KB 固定
	;mov	d [edi+8],0200h		;R/W タイプ / 特権レベル=0
	mov	eax,DOSENV_sel		;DOS 環境変数セレクタ
	call	make_mems		;メモリセレクタ作成 edi=構造体 eax=sel

	;-------------------------------
	;★DOSメモリセレクタ(in LDT)
	;-------------------------------
	mov	d [edi  ],0			;base
	mov	d [edi+4],(DOSMEMsize / 4096)-1	;1MB空間
	;mov	d [edi+8],0200h			;R/W タイプ / 特権レベル=0
	mov	eax,DOSMEM_Lsel			;DOS 環境変数セレクタ
	call	make_mems_4k			;メモリセレクタ作成 edi=構造体

;------------------------------------------------------------------------------
; Debug code
;------------------------------------------------------------------------------
Debug_code:
%if PRINT_TO_FILE
	xor	ecx, ecx
	mov	edx, .file
	mov	ah, 3ch
	int	21h	; Debug file create

	jmp	.skip
.file	db	"dump.txt",0
.skip:
%endif

%if PRINT_TSUGARU
	; https://nabe.adiary.jp/0619
	mov	dx, 2f10h
	mov	al, 5dh
	mov	ah, al
	out	dx, al
	in	al, dx
	not	al
	cmp	al, ah
	je	.enable_tsugaru_api	; is Tsugaru

	PRINT	.not_Tsugaru
	jmp	.skip

.not_Tsugaru	db	"This enviroment is not Tsugaru!",13,10,'$'
.enable_tsugaru_api:
	; Enable Tsugaru's VNDRV API
	mov	dx, 2f12h
	mov	al, 01h
	out	dx, al

	; Override int 21h ah=09h
	mov	eax, offset int_21h_09h_output_tsugaru
	mov	ebx, offset int21h_table
	add	ebx, 09h * 4	; ah=09h
	mov	[ebx], eax
.skip:
%endif

;------------------------------------------------------------------------------
;●各機種対応ルーチン
;------------------------------------------------------------------------------
%if TOWNS || PC_98 || PC_AT
	mov	b [init_machine], 1
	push	edx
	push	ebp
	push	fs
	push	gs

%if TOWNS
	call	setup_TOWNS		;TOWNS 固有の設定
%elif PC_98
	call	setup_PC98		;PC-98x1 固有の設定
%elif PC_AT
	call	setup_AT		;PC/AT互換機 固有の設定
%endif

	pop	gs
	pop	fs
	pop	ebp
	pop	edx
%endif

;------------------------------------------------------------------------------
;●パラメータ解析
;------------------------------------------------------------------------------
;[sub.asm]
;paras		dw	0,0		;発見したパラメーターの数
;paras_last	dw	0,0		;0dh の位置
;paras_p	resw	max_paras	;ポインタ配列
;
	mov	ecx,[paras]		;パラメータ数
	test	ecx,ecx			;値確認
	jz	no_file			;0 ならば jmp

	mov	edi,[work_adr]		;作業領域offset ロード
	xor	esi,esi			;MSBs (上位16ビット) 消去
	mov	eax,offset paras_p	;パラメータへのポインタ eax = argv

	align	4
para_analyze_loop:
	mov	si,[eax]		;パラメータへのポインタ esi = argv[N]
	cmp	b [esi],'-'		;比較
	jne	find_file		;'-' で始まらない文字列を file名とする

	;*** パラメータ解析ルーチン ***
	add	eax,byte (2)
	loop	para_analyze_loop

	align	4
no_file:
	mov	al, [show_TITLE]
	test	al, al
	jz	.skip
	PRINT		msg_10		;使い方表示
.skip:
	Program_END	00		;プログラム終了処理


	align	4
find_file:
	mov	al,[esi]		;
	mov	[edi],al		;ファイル名などを記録 -> work
	inc	esi
	inc	edi
	test	al,al
	jnz	find_file		;実行ファイル名をひたすら複写

	dec	esi			;最後の '0' の位置に戻す
	mov	ecx,[paras_last]	;末尾の位置
	mov	edi,81h			;PSP の引数先頭位置
	sub	ecx,esi			;末尾 - 現在位置
	mov	[80h],cl		;PSP に記録 / パラメタ長

	test	ecx,ecx			;ecx = 0?
	jz	para_copy_loop_exit

	align	4
para_copy_loop:
	mov	al,[esi]		;1 byte load
	inc	esi			;

	test	al,al
	jz	rec_space		;0 なら空白に復元

	mov	[edi],al		;記録
	inc	edi
	loop	para_copy_loop
	jmp	para_copy_loop_exit

	align	4
rec_space:
	mov	byte [edi],' '		;空白記録
	inc	edi
	loop	para_copy_loop

para_copy_loop_exit:
	mov	byte [edi],0dh		;終端記号


;------------------------------------------------------------------------------
;●EXP ファイル名の補完と検索
;------------------------------------------------------------------------------
	;
	;拡張子補完
	;
	mov	edi,[work_adr]

	align	4
find_period:
	mov	al,[edi]	;1 byte load
	inc	edi

	cmp	al,'.'		;if 拡張子発見?
	je	search_file	;  then jmp

	test	al,al		;0?
	jnz	find_period	

	;
	;拡張子の追加
	;
	mov	d [edi-1],EXP_EXT	;拡張子補完
	mov	b [edi+3],0		;終端記号

	;
	;ファイルの検索
	;
	align	4
search_file:
	;////// PATH386 の検索 /////////
	mov	al,[search_PATH386]	;検索する?
	test	al,al
	jz	.step

	mov	esi,[work_adr]		;検索ファイル名
	mov	ebx,offset env_PATH386	;環境変数名
	call	searchpath		;ファイル検索
	test	eax,eax			;結果判断
	je	.file_found		;ファイル発見 (jmp)

	;////// PATH の検索 ////////////
.step:	mov	al,[search_PATH]	;検索する?
	test	al,al
	jz	.step2

	mov	esi,[work_adr]		;検索ファイル名
	mov	ebx,offset env_PATH	;環境変数名
	call	searchpath		;ファイル検索
	test	eax,eax			;結果判断
	je	.file_found		;ファイル発見 (jmp)
	jmp	.not_found

	;////// カレントディレクトリの確認
.step2:
	mov	edx,[work_adr]		;検索したいファイル名のあるワーク
 	mov	 cl,6			;すべてのファイル
	mov	ah,4eh			;検索
	int	21h

	mov	edi,edx			;edi = ファイル名ポインタ
	jnc	.file_found		;発見したなら jmp

.not_found:
	;------ file_not_found ------
	PRINT	msg_05
	mov	edx,[work_adr]		;検索したファイル名
	call	string_print		;文字列表示 (null:終端)
	F386_end	22h

	;
	;ロードファイル名の表示
	;
	align	4
.file_found:
	mov	al,[verbose]		;冗長表示フラグ
	test	al,al			;0?
	jz	.no_verbose		;0 なら jmp

	PRINT	msg_05
	mov	edx,edi 		;ファイル名 string
	call	string_print		;文字列表示 (null:終端)
.no_verbose:

;------------------------------------------------------------------------------
;●EXP ファイルのロード
;------------------------------------------------------------------------------
call_load_exp:
	mov	esi,[work_adr]		;ワーク領域ロード
	call	load_exp		;EXP ファイルのロード
	jnc	.skip			;ロード成功なら EXP ファイルの実行

	mov	[f386err],al		;エラー番号記録
	xor	al,al
	mov	ah,4ch
	int	21h			;プログラム終了
.skip:

;------------------------------------------------------------------------------
;●EXP ファイル実行
;------------------------------------------------------------------------------
	jmp	NEAR run_exp

