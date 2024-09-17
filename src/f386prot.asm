;******************************************************************************
;　Free386 in protect mode
;******************************************************************************
;
BITS	32
;==============================================================================
; Start of protect mode
;==============================================================================
proc4 start32
	mov	ebx,F386_ds
	mov	 ds,bx
	mov	 es,bx
	mov	 fs,bx
	mov	 gs,bx
	lss	esp,[PM_stack_adr]

;------------------------------------------------------------------------------
; set intrrupt
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
	;Free386 original interrupt
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

	PRINT32	.not_Tsugaru
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
; initalize free memory bitmap
;------------------------------------------------------------------------------
proc1 init_free_memory_bitmap
	mov	ebx, [DOS_mem_ladr]
	mov	edx, [DOS_mem_pages]
	call	regist_free_memory

	mov	ebx, [EMB_physi_adr]
	mov	edx, [EMB_pages]
	call	regist_free_memory

	;
	; mapping phisical memory for ALLMEM_sel
	;
	mov	esi, [page_init_ladr]
	mov	ecx, [all_mem_pages]
	add	ecx, 0xff		;255pages
	xor	 cl, cl			;unit 1MB

	shl	ecx, 12
	mov	[page_init_ladr], ecx
	sub	ecx, esi		;sub mapped address
	shr	ecx, 12			;ecx = pages
	mov	edx, esi		;edx = phisical address
	call	set_physical_memory

;------------------------------------------------------------------------------
; Memory infomation
;------------------------------------------------------------------------------
proc1 memory_infomation
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
	mov	ebx, eax
	mov	eax, [EMB_physi_adr]
	call	rewrite_next_hash_to_hex
	shl	ebx, 10
	add	eax, ebx
	call	rewrite_next_hash_to_hex

	; allcated dos memory
	mov	eax, [DOS_alloc_sizep]
	mov	ebx, eax
	add	eax, b 1fh		;round up
	shr	eax, 10-4		;para to KB
	call	rewrite_next_hash_to_dec
	mov	eax, [DOS_alloc_seg]
	shl	eax, 4			;seg to linear address
	call	rewrite_next_hash_to_hex
	shl	ebx, 4
	add	eax, ebx
	call	rewrite_next_hash_to_hex

	; reserved dos memory
	movzx	eax, b [resv_real_memKB]
	call	rewrite_next_hash_to_dec

	PRINT32	msg_01
.skip:

;------------------------------------------------------------------------------
; more memory infomation
;------------------------------------------------------------------------------
proc1 more_memory_infomation
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
	mov	eax, [V86int_table_adr]
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

	; GP buffer
	mov	eax, [gp_buffer_table]
	call	rewrite_next_hash_to_hex
	add	eax,  GP_BUFFER_SIZE * GP_BUFFERS -1
	call	rewrite_next_hash_to_hex
	mov	eax,  GP_BUFFER_SIZE
	call	rewrite_next_hash_to_dec

	; stack info
	mov	eax, [sw_stack_bottom_orig]
	sub	eax,  SW_stack_size * SW_max_nest
	call	rewrite_next_hash_to_hex
	add	eax,  SW_stack_size * SW_max_nest -1
	call	rewrite_next_hash_to_hex
	mov	eax,  SW_stack_size
	call	rewrite_next_hash_to_dec

	mov	eax, [safe_stack_adr]
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

	; free RAM bitmap
	mov	eax, [freeRAM_bm_ladr]
	call	rewrite_next_hash_to_hex
	mov	eax, [freeRAM_bm_size]
	call	rewrite_next_hash_to_dec

	PRINT32	msg_02
.skip:

;------------------------------------------------------------------------------
;●セレクタの作成（LDT内 セレクタ）
;------------------------------------------------------------------------------
	;-------------------------------
	;★PSPセレクタの作成
	;-------------------------------
	mov	edi,[work_adr]		;ワークアドレスロード
	mov	eax,[top_ladr]		;プログラム先頭リニアアドレス
	mov	d [edi+4],256		;256 byte
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
	mov	d [edi  ],ebx		;base
	mov	d [edi+4],eax		;size
	;mov	d [edi+8],0200h		;R/W タイプ / 特権レベル=0
	mov	eax,DOSENV_sel		;DOS 環境変数セレクタ
	call	make_selector		;メモリセレクタ作成 edi=構造体 eax=sel

	;-------------------------------
	;★DOSメモリセレクタ(in LDT)
	;-------------------------------
	mov	d [edi  ],0			;base
	mov	d [edi+4],DOSMEMsize / 4096	;1MB空間
	;mov	d [edi+8],0200h			;R/W タイプ / 特権レベル=0
	mov	eax,DOSMEM_Lsel			;DOS 環境変数セレクタ
	call	make_selector_4k		;メモリセレクタ作成 edi=構造体

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
proc1 copy_exp_filename_to_work
	mov	esi, [exp_name_adr]	; file name, no terminate
	mov	ecx, [exp_name_len]	;
	mov	edi, [work_adr]
	test	ecx, ecx
	jnz	.exists_name

	mov	al, [show_title]
	test	al, al
	jz	.skip
	PRINT32	msg_10			; show help
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
proc1 copy_exp_pamameter
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
proc4 rewrite_command_name
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
proc1 completes_exp_file_name
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
proc1 search_exp_file
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
	call	search_path_env
	jnc 	.found
.skip_path386:

	;--------------------------------------------------
	; check PATH
	;--------------------------------------------------
	cmp	byte [search_PATH], 0
	je	.skip_path

	mov	ebx, offset env_PATH	; [ebx] = "PATH"
	call	search_path_env
	jnc	.found
.skip_path:
.not_found:
	;--------------------------------------------------
	; file not found
	;--------------------------------------------------
	PRINT32	msg_05
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

	PRINT32	msg_05
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
proc4 abort_32
	mov	ah, 25
	jmp	short error_exit_32
proc4 exit_32
	mov	ah, 0
proc4 error_exit_32
	cli
	cld
	mov	bx,F386_ds		;ds 復元
	mov	ds,bx			;
	mov	es,bx			;VCPI で切り換え時、
	mov	fs,bx			;セグメントレジスタは不定値
	mov	gs,bx			;
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
	push	DOSMEM_sel			;DOS メモリアクセスレジスタ
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

;------------------------------------------------------------------------------
;goto V86(16bit) mode
;------------------------------------------------------------------------------
proc4	exit_to_V86_mode
	cli
	cmp	b [use_vcpi], 0
	jz	exit_to_16bit_mode

	;///////////////////////////////
	;V86 モードへ戻る
	;///////////////////////////////
	mov	eax,[V86_cs]		;V86時 cs,ds
	mov	ebx,[V86_sp]		;V86時 sp

	push	eax			;V86 gs
	push	eax			;V86 fs
	push	eax			;V86 ds
	push	eax			;V86 es
	push	eax			;V86 ss
	push	ebx			;V86 esp
	pushfd				;eflags
	push	eax			;V86 cs
	push	offset exit_16 ;V86 EIP / 終了ラベル

	mov	ax,0de0ch		;VCPI function 0ch / to V86 mode
	call    far [VCPI_entry]	;VCPI call


proc4	exit_to_16bit_mode
	db	0eah			;far jmp
	dd	offset .286		;
	dw	F386_cs286		;286 code segment

	BITS	16
.286:
	lidt	cs:[RM_LIDT_data]

	mov	ebx, [V86_cs]
	mov	[.seg], bx

	;clear shadow D bit of selectors
	mov	ax, F386_ds286
	mov	ds, ax
	mov	es, ax
	mov	fs, ax
	mov	gs, ax
	mov	ss, ax

	mov	eax,cr0
	and	eax,07ffffffeh		;PG=PE=0
	mov	cr0,eax

	db	0eah			;far jmp
	dw	offset .16		;
.seg	dw	0000h			;real mode segment

.16:
	mov	ds, bx
	mov	es, bx
	mov	fs, bx
	mov	gs, bx
	mov	ss, bx
	mov	sp, [V86_sp]
	jmp	exit_16

	BITS	32

