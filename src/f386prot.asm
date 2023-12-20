;******************************************************************************
;　Free386 in protect mode
;******************************************************************************
;
BITS	32
;==============================================================================
;★プロテクトモード スタートラベル
;==============================================================================
proc32 start32
	mov	ebx,F386_ds		;ds セレクタ
	mov	 ds,bx			;ds ロード
	mov	 es,bx			;es
	mov	 fs,bx			;fs
	mov	 gs,bx			;gs
	lss	esp,[PM_stack_adr]	;スタックポインタロード

;------------------------------------------------------------------------------
;●割り込み設定
;------------------------------------------------------------------------------
	;///////////////////////////////
	;hook int 22h/23h
	;///////////////////////////////
	mov	eax,2506h		;常にプロテクトモードで発生する割り込み
	mov	 cl,23h			;CTRL-C 割り込み
	mov	edx,offset abort_32	;hook 先ルーチン

	push	cs
	pop	ds			;ds:edx = エトリーアドレス
	int	21h

	mov	 ds,bx			;recovery ds

	;///////////////////////////////
	;Free386 独自割り込みの設定
	;///////////////////////////////
	call	setup_F386_int		;see int_f386.asm

	sti

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
.file	db	DUMP_FILE,0
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
; Memory infomation
;------------------------------------------------------------------------------
proc8 memory_infomation
	cmp	b [verbose], 0
	jz	near .skip

	mov	edi, offset msg_01

	; memory info
	mov	eax, [all_mem_pages]
	shl	eax, 2				;page to KB
	call	rewrite_next_hash_to_dec

	; allocated protect memory
	mov	eax, [max_EMB_free]
	call	rewrite_next_hash_to_dec
	mov	eax, [EMB_physi_adr]
	call	rewrite_next_hash_to_hex

	; allcated dos memory
	mov	eax, [DOS_alloc_sizep]
	add	eax, b 1fh		;round up
	shr	eax, 10-4		;para to KB
	call	rewrite_next_hash_to_dec
	mov	eax, [DOS_alloc_seg]
	shl	eax, 4			;seg to linear address
	call	rewrite_next_hash_to_hex

	; reserved dos memory
	movzx	eax, b [resv_real_memKB]
	call	rewrite_next_hash_to_dec

	PRINT	msg_01
.skip:

;------------------------------------------------------------------------------
; more memory infomation
;------------------------------------------------------------------------------
proc8 more_memory_infomation
	cmp	b [verbose], 1
	jbe	near .skip

	mov	edi, offset msg_02

	; program code offset
	mov	eax, end_adr
	dec	eax
	call	rewrite_next_hash_to_hex

	mov	eax, [V86_cs]
	call	rewrite_next_hash_to_hex

	; all heap memory
	mov	eax, end_adr
	call	rewrite_next_hash_to_hex

	mov	eax, 10000h
	sub	eax, end_adr
	call	rewrite_next_hash_to_dec

	; free heap memory
	mov	ebx, [free_heap_top]
	mov	edx, [free_heap_bottom]

	mov	eax, ebx
	call	rewrite_next_hash_to_hex
	mov	eax, edx
	dec	eax
	call	rewrite_next_hash_to_hex

	mov	eax, edx
	sub	eax, ebx
	call	rewrite_next_hash_to_dec

	; Real mode vectors backup
	mov	eax, [RVects_save_adr]
	call	rewrite_next_hash_to_hex
	add	eax,  IntVectors *4 -1
	call	rewrite_next_hash_to_hex

	; Real mode interrupt hook routines
	mov	eax, [rint_labels_adr]
	call	rewrite_next_hash_to_hex
	add	eax, IntVectors *4 -1
	call	rewrite_next_hash_to_hex

	; GDT/LDT/IDT/TSS
	mov	eax, [GDT_adr]
	call	rewrite_next_hash_to_hex
	mov	eax, [LDT_adr]
	call	rewrite_next_hash_to_hex
	mov	eax, [IDT_adr]
	call	rewrite_next_hash_to_hex
	mov	eax, [TSS_adr]
	call	rewrite_next_hash_to_hex

	add	eax, TSSsize -1
	call	rewrite_next_hash_to_hex

	; main call buffer
	mov	eax, [call_buf_adr32]
	mov	ebx, [call_buf_size]
	call	rewrite_next_hash_to_hex
	add	eax, ebx
	dec	eax
	call	rewrite_next_hash_to_hex
	mov	eax, ebx
	call	rewrite_next_hash_to_dec

	; work memory
	mov	eax, [work_adr]
	call	rewrite_next_hash_to_hex
	add	eax,  WORK_size -1
	call	rewrite_next_hash_to_hex

	; stack info
	mov	eax, [sw_stack_bottom_orig]
	sub	eax,  SW_stack_size * SW_max_nest
	call	rewrite_next_hash_to_hex
	add	eax,  SW_stack_size * SW_max_nest -1
	call	rewrite_next_hash_to_hex
	mov	eax,  SW_stack_size
	call	rewrite_next_hash_to_dec

	mov	eax, [VCPI_stack_adr]
	sub	eax,  VCPI_stack_size
	call	rewrite_next_hash_to_hex

	mov	eax, [PM_stack_adr]
	sub	eax,  PM_stack_size
	call	rewrite_next_hash_to_hex

	movzx	eax, w [V86_sp]
	sub	eax, V86_stack_size
	call	rewrite_next_hash_to_hex

	; user call buffer
	mov	ebx, [user_cbuf_adr16]
	mov	eax, ebx
	shr	eax, 16
	call	rewrite_next_hash_to_hex
	mov	 ax, bx
	call	rewrite_next_hash_to_hex
	movzx	eax, b [user_cbuf_pages]
	shl	eax, 12
	call	rewrite_next_hash_to_dec

	PRINT	msg_02
.skip:

;------------------------------------------------------------------------------
;●メモリ管理の設定
;------------------------------------------------------------------------------
	mov	eax,[EMB_pages]		;EMBメモリページ数
	mov	edx,[EMB_physi_adr]	;空き物理メモリ先頭
	mov	[free_RAM_pages] ,eax	;全プロテクトメモリとして使用する
	mov	[free_RAM_padr]  ,edx	;空き先頭物理メモリ先頭アドレス

;------------------------------------------------------------------------------
;●全メモリを示すセレクタを作成
;------------------------------------------------------------------------------
proc8 make_all_mem_sel
	mov	ecx,[all_mem_pages]	;eax <- 総メモリページ数
	mov	edx,ecx
	mov	edi,[work_adr]		;ワークメモリ
	dec	edx			;edx = limit値 ( /pages)
	mov	d [edi  ],0		;
	mov	d [edi+4],edx		;
	mov	d [edi+8],0200h		;メモリタイプ / 特権レベル=0

	mov	eax,ALLMEM_sel		;全メモリアクセスセレクタ
	call	make_selector_4k		;メモリセレクタ作成 edi=構造体 eax=sel

	;
	;全メモリセレクタ作成後に以下は実行
	;
	;mov	ecx,[all_mem_pages]	;eax <- 総メモリページ数
	mov	esi,[free_liner_adr]	;空きリニアアドレス
	mov	edx,esi			;物理アドレスと1対1

	add	ecx,0xff		;255pages
	xor	 cl,cl			;1MB単位に切り上げ
	shl	ecx,12			;eax = 物理アドレス最大値
	mov	[free_liner_adr],ecx	;空きリニアアドレス更新
	sub	ecx,esi			;割り当てるメモリサイズ
	shr	ecx,12			;割り当てるページ数

	; esi = 張りつけ先リニアアドレス
	; edx = 張りつける物理アドレス
	; ecx = 張りつけるページ数
	call	set_physical_mem

patch_for_386sx:
	mov	al, [cpu_is_386sx]
	test	al, al
	jz	.skip			;386SX is 24bit address bus.
	mov	eax, 01000000h		;Therefore, addresses over 1000000h are always free.
	mov	[free_liner_adr],eax
.skip:

;------------------------------------------------------------------------------
;●セレクタの作成（LDT内 セレクタ）
;------------------------------------------------------------------------------
	;-------------------------------
	;★PSPセレクタの作成
	;-------------------------------
	mov	edi,[work_adr]		;ワークアドレスロード
	mov	eax,[top_ladr]		;プログラム先頭リニアアドレス
	mov	d [edi+4],256 -1	;limit
	mov	d [edi  ],eax		;base
	mov	d [edi+8],0200h		;R/W タイプ / 特権レベル=0
	mov	eax,PSP_sel1		;PSP セレクタ1
	call	make_selector		;メモリセレクタ作成 edi=構造体 eax=sel
	mov	eax,PSP_sel2		;PSP セレクタ2
	call	make_selector		;メモリセレクタ作成 edi=構造体 eax=sel

	;-------------------------------
	;★DOS環境変数セレクタの作成
	;-------------------------------
	xor	ebx,ebx
	mov	eax,DOSMEM_sel		;DOS メモリアクセスセレクタ
	mov	  fs,ax			;fs に代入

	mov	 bx,[2Ch]		;下位 2バイト = ENV のセグメント
	shl	ebx,4			;16 倍してリニアアドレスへ
	mov	 ax,[fs:ebx -16 + 3]	;PSP のサイズ / MCB を参照している
	shl	eax,4			;16 倍 para -> byte
	dec	eax			;size -> limit 値
	mov	d [edi  ],ebx		;base
	mov	d [edi+4],eax		;limit / 32KB 固定
	;mov	d [edi+8],0200h		;R/W タイプ / 特権レベル=0
	mov	eax,DOSENV_sel		;DOS 環境変数セレクタ
	call	make_selector		;メモリセレクタ作成 edi=構造体 eax=sel

	;-------------------------------
	;★DOSメモリセレクタ(in LDT)
	;-------------------------------
	mov	d [edi  ],0			;base
	mov	d [edi+4],(DOSMEMsize / 4096)-1	;1MB空間
	;mov	d [edi+8],0200h			;R/W タイプ / 特権レベル=0
	mov	eax,DOSMEM_Lsel			;DOS 環境変数セレクタ
	call	make_selector_4k			;メモリセレクタ作成 edi=構造体

;------------------------------------------------------------------------------
;●各機種対応ルーチン
;------------------------------------------------------------------------------
%if TOWNS || PC_98 || PC_AT
	mov	b [init_machine32], 1
	%if TOWNS
		call	init_TOWNS_32
	%elif PC_98
		call	init_PC98_32
	%elif PC_AT
		call	init_AT_32
	%endif
%endif

;------------------------------------------------------------------------------
; copy exp name to work
;------------------------------------------------------------------------------
proc8 copy_exp_filename_to_work
	mov	esi, [exp_name_adr]	; file name, no terminate
	mov	ecx, [exp_name_len]	;
	mov	edi, [work_adr]
	test	ecx, ecx
	jnz	.exists_name

	mov	al, [show_title]
	test	al, al
	jz	.skip
	PRINT	msg_10			; show help
.skip:
	jmp	exit_32

.exists_name:
	;
	; copy [esi] to [edi]
	; and check file name include "\" or ":"
	;
	mov	[exp_name_fname_offset], edi
.loop:
	lodsb				; al = [esi++]
	stosb				; [edi++] = al
	cmp	al, '\'
	je	.is_path
	cmp	al, ':'
	je	.is_path
	loop	.loop
	jmp	short .exit

.is_path:
	mov	byte [exp_name_include_path], 1
	mov	     [exp_name_fname_offset], edi
	loop	.loop

.exit:
	mov	byte [edi], 0

;------------------------------------------------------------------------------
; copy parameter PSP to PSP
;------------------------------------------------------------------------------
proc8 copy_exp_pamameter
	mov	edi, 81h
	mov	ecx, 7eh

	cmp	b [esi], ' '
	jnz	short .copy_loop
	inc	esi			; skip first space

.copy_loop:
	mov	al, [esi]		; 1 byte load
	mov	[edi], al
	cmp	al, 0dh
	jz	.copy_end

	inc	esi
	inc	edi
	loop	.copy_loop

.copy_end:
	mov	byte [edi], 0dh
	mov	eax, edi
	sub	al, 81h
	mov	[80h], al		; parameter length


;------------------------------------------------------------------------------
; rewrite argv[0] is command name
;------------------------------------------------------------------------------
;	ENV領域が足りず書ききれない場合は、途中で諦める。
;
proc32 rewrite_command_name
	mov	ebx, err_00		; set non exists ENV name string
	call	search_env		; ret fs:[edx] is ENV end

	cmp	word fs:[edx], 0001h
	jne	.exit
	add	edx, byte 2

	;
	; copy exp command line name to ENV
	;
	mov	esi, [exp_name_fname_offset]

	xor	eax, eax
	mov	 ax, fs
	lsl	ecx, ax
	sub	ecx, edx		; ecx = remain bytes
	jbe	.exit			; safety

.loop:
	lodsb				; al = [esi++]
	mov	fs:[edx], al		; store
	inc	edx
	loop	.loop

	mov	b fs:[edx], 0		; last byte force write '0'
.exit:

;------------------------------------------------------------------------------
; Completes EXP file extensions
;------------------------------------------------------------------------------
proc8 completes_exp_file_name
	mov	edi, [exp_name_fname_offset]
.loop:
	mov	al, [edi]
	inc	edi

	cmp	al,'.'
	je	short .exist_ext

	test	al,al
	jnz	.loop

	;
	; add file extension
	;
	mov	dword [edi-1], EXP_EXT
	mov	byte  [edi+3], 0	; null

.exist_ext:

;------------------------------------------------------------------------------
; search exp file
;------------------------------------------------------------------------------
proc8 search_exp_file
	;--------------------------------------------------
	; read command line name
	;--------------------------------------------------
	mov	edi, [work_adr]		; edi = file name
	call	check_readable_file
	jnc	.found

	;--------------------------------------------------
	; search
	;--------------------------------------------------
	mov	esi, [work_adr]		; esi = search file name
	mov	edi, esi
	add	edi, 100h		; edi = result store buffer

	cmp	byte [exp_name_include_path], 0
	jne	.not_found

	;--------------------------------------------------
	; check PATH386
	;--------------------------------------------------
	cmp	byte [search_PATH386], 0
	je	.skip_path386

	mov	ebx, offset env_PATH386	; [ebx] = "PATH386"
	call	search_path
	jnc 	.found
.skip_path386:

	;--------------------------------------------------
	; check PATH
	;--------------------------------------------------
	cmp	byte [search_PATH], 0
	je	.skip_path

	mov	ebx, offset env_PATH	; [ebx] = "PATH"
	call	search_path
	jnc	.found
.skip_path:
.not_found:
	;--------------------------------------------------
	; file not found
	;--------------------------------------------------
	PRINT	msg_05
	mov	edx, esi		; search file name
	call	print_string_32

	mov	ah, 21			;'Can not read executable file'
	jmp	error_exit_32

	;--------------------------------------------------
	; file found
	;--------------------------------------------------
.found:
	mov	al,[verbose]		;冗長表示フラグ
	test	al,al			;0?
	jz	.no_verbose		;0 なら jmp

	PRINT	msg_05
	mov	edx,edi 		;ファイル名 string
	call	print_string_32		;文字列表示 (null:終端)
.no_verbose:

;------------------------------------------------------------------------------
;load and run EXP
;------------------------------------------------------------------------------
	mov	edx, edi		;edx = load file PATH
	mov	esi, [work_adr]		;esi = work address
	call	load_exp
	jc	error_exit_32		;ah = internal error code

	jmp	NEAR run_exp

;------------------------------------------------------------------------------
;●プログラムの終了(32bit)
;------------------------------------------------------------------------------
proc32 abort_32
	mov	ah, 25
	jmp	short error_exit_32
proc32 exit_32
	mov	ah, 0
proc32 error_exit_32
	cli
	mov	bx,F386_ds		;ds 復元
	mov	 ds,bx			;
	mov	 es,bx			;VCPI で切り換え時、
	mov	 fs,bx			;セグメントレジスタは不定値
	mov	 gs,bx			;
	lss	esp,[PM_stack_adr]	;スタックポインタロード

	mov	[err_level],ax
	;mov	[err_level],al		;save error level
	;mov	[f386err],ah

	;///////////////////////////////
	;終了処理でエラーを発生させないためにバッファ関連クリア
	;///////////////////////////////
	call	clear_gp_buffer_32
	call	clear_sw_stack_32

	;///////////////////////////////
	;各機種固有の終了処理
	;///////////////////////////////
	%if TOWNS || PC_98 || PC_AT
		cmp	b [init_machine32], 0
		je	.skip_exit_machine
		mov	b [init_machine32], 0		;Re-entry prevention

		%if TOWNS
			call	exit_TOWNS_32
		%elif PC_98
			call	exit_PC98_32
		%elif PC_AT
			call	exit_AT_32
		%endif
	.skip_exit_machine:
	%endif

	;///////////////////////////////
	;リアルモードベクタの復元
	;///////////////////////////////
%if RestoreRealVec
RestoreRealVectors:
	push	d (DOSMEM_sel)			;DOS メモリアクセスレジスタ
	pop	fs				;load
	mov	ecx,IntVectors			;ベクタ数
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
	mov	eax,[V86_cs]		;V86時 cs,ds
	mov	ebx,[V86_sp]		;V86時 sp

	cli				;割り込み禁止
	push	eax			;V86 gs
	push	eax			;V86 fs
	push	eax			;V86 ds
	push	eax			;V86 es
	push	eax			;V86 ss
	push	ebx			;V86 esp
	pushfd				;eflags
	push	eax			 ;V86 cs
	push	d (offset exit_16) ;V86 EIP / 終了ラベル

	mov	ax,0de0ch		;VCPI function 0ch / to V86 mode
	call    far [VCPI_entry]	;VCPI call

