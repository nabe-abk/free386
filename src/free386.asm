;******************************************************************************
;　Free386 (compatible to RUN386 DOS-Extender)
;		'ABK project' all right reserved. Copyright (C)nabe@abk
;******************************************************************************
;[TAB=8]
;
%include	"macro.inc"
%include	"f386def.inc"

%include	"start.inc"
%include	"sub.inc"
%include	"sub32.inc"
%include	"memory.inc"
%include	"selector.inc"
%include	"call_v86.inc"
%include	"int.inc"

; PC model dependent
%include	"pc.inc"

;******************************************************************************
; global symbols
;******************************************************************************

;--- for selector.asm ------------------------------
global		GDT_adr
global		LDT_adr
global		page_dir_ladr
global		free_liner_adr
global		free_RAM_padr
global		free_RAM_pages

;--- for call_v86.asm -----------------------------
global		to_PM_EIP
global		to_PM_data_ladr
global		VCPI_entry
global		VCPI_stack_adr
global		V86_cs

;--- for int.asm ----------------------------------
global		IDT_adr
global		PM_stack_adr
global		RVects_flag_tbl
global		DTA_off
global		DTA_seg
global		default_API
global		pharlap_version

global		call_buf_used
global		call_buf_size
global		call_buf_adr16
global		call_buf_seg16
global		call_buf_adr32

global		user_cbuf_adr16
global		user_cbuf_seg16
global		user_cbuf_ladr

%ifdef USE_VCPI_8259A_API
global		vcpi_8259m
global		vcpi_8259s
%endif

;--- other ----------------------------------------
global		error_exit_16
global		exit_32
global		error_exit_32

global		top_ladr
global		end_adr
global		work_adr

global		all_mem_pages
global		cpu_is_386sx

;******************************************************************************
;■コード(16 bit)
;******************************************************************************
seg16	text class=CODE align=4 use16
;------------------------------------------------------------------------------
; start
;------------------------------------------------------------------------------
	global	start
start:
	xor	eax,eax

	mov	ax,cs		; check ".exe" or ".com"
	mov	bx,ds
	cmp	ax,bx		; cs <=> ds
	je	.step		; 

	mov	ds,ax
	mov	ah,01		;'please run free386.com'
	jmp	error_exit_16

.step:
	shl	eax, 4		; seg to linear address
	mov	[top_ladr], eax	; save

	;///////////////////////////////
	;64KB以上のDOSメモリ開放
	;///////////////////////////////
	mov	bx,1000h		;64KB / 16
	mov	ah,4ah			;メモリブロックサイズの変更
	int	21h			;DOS call

;------------------------------------------------------------------------------
;●パラメタ確認 (free386 への動作指定)
;------------------------------------------------------------------------------
proc2 parameter_check
	mov	si, 81h			;argument string pointer
	mov	bp, 7fh			;argument max length
	xor	bx, bx

	jmp	short .loop

	;///////////////////////////////
	; set PharLap version to 2.2 (compatible EXE386)
	;///////////////////////////////
.para_2:
	mov	d [pharlap_version], 20643232h	; ' d22'
	jmp	short .loop

	;///////////////////////////////
	; -m : Use memory maximum
	;///////////////////////////////
.para_m:
	mov	b [pool_for_paging], 1	;ページング用プールメモリ
	mov	w [resv_real_memKB], 0	;reserved dos memory = 0
	jmp	short .loop
	;/// Move some parameters to this location. Because does not fit in jmp short.
	;/// jmp short に収まらないので一部解析をここに記述

.para_maxreal:
.para_minreal:
.para_callbuf:
	add	si, bx
	call	get_next_parameter	;skip next parameter
	jmp	short .loop

.sp_param:
	; RUN386 some parameters
	cmp	eax, 'maxr'
	je	.para_maxreal
	cmp	eax, 'minr'
	je	.para_minreal
	cmp	eax, 'call'
	je	.para_callbuf
	jmp	short .sp_param_return

.loop:
	add	si, bx
	call	get_next_parameter	;si=string, bx=length
	test	bx, bx
	jz	.end_paras		;0

	cmp	b [si],'-'		;'-' parameter?
	jne	.end_paras		;

	mov	eax,[si+1]		;load 4 byte

	jmp	short .sp_param		;for short jump
	.sp_param_return:		;

	cmp	al,'v'
	je	.para_v
	cmp	al,'q'
	je	.para_q
	cmp	al,'p'
	je	.para_p
	cmp	al,'c'
	je	.para_c
	cmp	al,'m'
	je	.para_m
	cmp	al,'2'
	je	.para_2
%if TOWNS
	cmp	al,'n'
	je	.para_n
%endif
	cmp	al,'i'
	je	.para_i
	jmp	short .loop

	;///////////////////////////////
	; -v
	;///////////////////////////////
.para_v:
	cmp	ah,'v'			; -vv?
	je	.v0
	mov	ah,01
.v0:
	mov	b [verbose],ah
	jmp	short .loop

	;///////////////////////////////
	; -q
	;///////////////////////////////
.para_q:
	mov	b [show_title],0	;no title output
	jmp	short .loop

	;///////////////////////////////
	; -p?
	;///////////////////////////////
.para_p:
	and	ah,01			;-p? / al = ?
	mov	[search_PATH],ah	;search PATH flag
	jmp	short .loop

	;///////////////////////////////
	; -c?
	;///////////////////////////////
.para_c:
	test	ah,ah			;-c? / al = ?
	jnz	.c0			
	mov	ah,01			;指定なしなら -c1 と解釈
.c0:	and	ah,03			;bit 1,0 取り出し
	mov	[reset_CRTC],ah
	jmp	short .loop

%if TOWNS
	;///////////////////////////////
	; -n, do not load CoCo/NSD
	;///////////////////////////////
.para_n:
	and	ah,01h			;al = -n?
	mov	b [load_nsdd],ah
	jmp	short .loop
%endif

	;///////////////////////////////
	; -i?
	;///////////////////////////////
.para_i:
	and	ah,01			;-i? / al = ?
	mov	b [check_MACHINE],ah
	jmp	short .loop

	;///////////////////////////////
	; save exp file name
	;///////////////////////////////
.end_paras:
	mov	[exp_name_adr], si
	mov	[exp_name_len], bx


;------------------------------------------------------------------------------
;●タイトル表示
;------------------------------------------------------------------------------
proc2 print_title
	mov	al,[show_title]	;タイトル表示する?
	test	al,al		;値 check
	jz	.no_title	;0 なら表示せず
	PRINT16	P_title		;タイトル表示
.no_title:

	cmp	b [verbose], 2
	jb	.skip

	mov	ax, cs		; number
	mov	cx, 4		; digits
	mov	di, seg_hex	; store target
	call	bin2hex_16
	PRINT16	seg_msg
.skip:

;------------------------------------------------------------------------------
;●簡易機種判別
;------------------------------------------------------------------------------
%if MACHINE_CODE			;機種汎用でない

proc1 machine_check
	mov	al,[check_MACHINE]	;機種判別フラグ
	test	al,al			;値確認
	jz	.no_check		;0 ならチェックしない

	%if TOWNS
		call	check_TOWNS_16
	%elif PC_98
		call	check_PC98_16
	%elif PC_AT
		call	check_AT_16
	%endif

	jnc	.check_true		;Cy=0 なら該当機種
	mov	ah, 02			;機種判別失敗
	jmp	error_exit_16		;終了

.no_check:
.check_true:
%endif

;------------------------------------------------------------------------------
;●VCPI の存在確認
;------------------------------------------------------------------------------
%if CHECK_EMS
proc1 check_ems_driver
	;
	; check EMS
	;
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

.not_found:
	mov	ah, 03		; 'EMS not found'
	jmp	error_exit_16

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

	mov	ah, 04		; 'VCPI not found'
	jmp	error_exit_16
.skip:

;------------------------------------------------------------------------------
;●メモリ総量の取得 / VCPI
;------------------------------------------------------------------------------
get_vcip_memory_size:
	mov	ax,0de02h			;VCPI function 02h
	int	67h				;最上位ページの物理アドレス
	shr	edx,12				;アドレス -> page
	inc	edx				;edx = 総メモリページ数

	mov	eax, MAX_RAM /4096		;最大メモリ量制限
	cmp	edx, eax
	jb	short .step
	mov	edx, eax
.step:
	mov	[all_mem_pages],edx		;値記録

;------------------------------------------------------------------------------
;●スタックメモリの確保と設定
;------------------------------------------------------------------------------
	mov	cl, 11			;error code for stack_malloc

	mov	ax,V86_stack_size	;V86時 stack
	call	stack_malloc		;下位メモリ割り当て
	mov	sp,di			;スタック切替え

	mov	[V86_cs],cs		;cs 退避
	mov	[V86_sp],di		;sp 退避

	mov	ax,PM_stack_size	;プロテクトモード時 stack
	call	stack_malloc		;下位メモリ割り当て
	mov	[PM_stack_adr],di	;記録

	mov	ax,VCPI_stack_size	;CPU Prot->V86 切り換え時専用 stack
	call	stack_malloc		;下位メモリ割り当て
	mov	[VCPI_stack_adr],di	;記録

	; CPU mode change stack
	mov	ax, SW_stack_size * SW_max_nest
	call	stack_malloc
	mov	[sw_stack_bottom]     ,di
	mov	[sw_stack_bottom_orig],di

;------------------------------------------------------------------------------
; Memory setting
;------------------------------------------------------------------------------
proc1 memory_setting
	;//////////////////////////////////////////////////
	; Save real mode interrupt table: 0000:0000-03ff
	;//////////////////////////////////////////////////
	xor	edi,edi
	mov	ax, IntVectors *4
	mov	cl, 11			; error code for heap_malloc
	call	heap_malloc
	mov	[RVects_save_adr],di	; save address

	; copy
	push	ds
	xor	esi,esi			; source
	mov	 ds,si			; ds = 0
	mov	ecx,IntVectors
	rep	movsd			; es:edi <- ds:esi
	pop	ds

	;//////////////////////////////////////////////////
	; alloc real mode int hook memory and other setup
	;//////////////////////////////////////////////////
	call	setup_cv86		;in call_v86.asm

	;//////////////////////////////////////////////////
	;GDT/LDT/TSS
	;//////////////////////////////////////////////////
	mov	cl, 11			;error code for heap_malloc

	mov	ax,GDTsize		;Global Descriptor Table's size
	call	heap_calloc
	mov	[GDT_adr],di

	mov	ax,LDTsize		;Local Descriptor Table's size
	call	heap_calloc
	mov	[LDT_adr],di

	mov	ax,IDTsize		;Interrupt Descriptor Table's size
	call	heap_calloc
	mov	[IDT_adr],di

	mov	ax,TSSsize		;Task State Segment's size
	call	heap_calloc
	mov	[TSS_adr],di

	;//////////////////////////////////////////////////
	; main call buffer
	;//////////////////////////////////////////////////
	movzx	eax, b [call_buf_sizeKB]
	shl	eax, 10
	cmp	eax, 10000h
	jb	.cb_skip
	mov	eax, 0ffffh
.cb_skip:
	mov	cl, 12			;error code: 'CALL buufer allocation failed'
	mov	[call_buf_size], eax
	call	heap_malloc

	mov	[call_buf_seg16], ds	; real segment
	mov	[call_buf_adr16], di	; offset
	mov	[call_buf_adr32], di	; offset

	;//////////////////////////////////////////////////
	; Universal buffer
	;//////////////////////////////////////////////////
	mov	cl, 12			;error code for heap_malloc
	mov	ax, WORK_size
	call	heap_malloc
	mov	[work_adr],di

	mov	cx, GP_BUFFERS
	mov	si, offset gp_buffer_table
.gp_loop:
	mov	ax, GP_BUFFER_SIZE
	call	heap_malloc
	mov	[si], di	; save
	add	si, 4
	loop	.gp_loop

	mov	b [gp_buffer_remain], GP_BUFFERS

;------------------------------------------------------------------------------
;●機種固有の初期化設定（メモリ設定済後、XMS直前）
;------------------------------------------------------------------------------

%if TOWNS
	call	init_TOWNS_16
%elif PC_98
	call	init_PC98_16
%elif PC_AT
	call	init_AT_16
%endif

;------------------------------------------------------------------------------
;●XMS の確認と呼び出しアドレスの取得
;------------------------------------------------------------------------------
XMS_setup:
	mov	ax,4300h	;AH=43h : XMS
	int	2fh		;2fh call
	cmp	al,80h		;XMS install?
	je	.found		;等しければ jmp

	mov	ah, 05		;'XMS not found'
	jmp	error_exit_16

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
%if USE_XMS20
proc1 get_EMB_XMS20
	test	al,al		;冗長な表示?
	jz	.step		;0 なら jmp
	PRINT16	msg_06		;'Found XMS 2.0'

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
%endif

	;///////////////////////
	;メモリ確保失敗
	;///////////////////////
get_EMB_failed:
	mov	ah, 06		; 'XMS memory allocation failed'
	jmp	error_exit_16


;------------------------------------------------------------------------------
;●拡張メモリの確保 (use XMS3.0)
;------------------------------------------------------------------------------
proc1 get_EMB_XMS30
	test	al,al		;冗長な表示?
	jz	.step		;0 なら jmp
	PRINT16	msg_07		;'Found XMS 3.0'

.step:
	mov	ah,88h			;EMB 空きメモリ問い合わせ
	XMS_function			;XMS call
	test	bl,bl			;bl の値確認
	jnz	get_EMB_failed		;non 0 なら jmp

	mov	[max_EMB_free]  ,eax	;最大長、空きメモリサイズ (KB)
	mov	[total_EMB_free],edx	;総空きメモリサイズ (KB)
	mov	[EMB_top_adr]   ,ecx	;管理する最上位アドレス // ecx=0の模様

	mov	edx,eax			;edx = 確保するメモリサイズ
	mov	ah,89h			;最大連続空きメモリを全て確保
	XMS_function			;確保
	test	ax,ax			;ax = 0?
	jz	get_EMB_failed		;0 なら確保失敗
	mov	[EMB_handle],dx		;EMBハンドルをセーブ

;------------------------------------------------------------------------------
;●確保した拡張メモリのロック と 拡張メモリの初期情報設定
;------------------------------------------------------------------------------
proc1 lock_EMB
	mov	ah,0ch		;EMB memory lock
	XMS_function		;
	test	ax,ax		;ax = 0?
	jnz	.skip		;non 0 is success

	mov	ah, 07		;'XMS memory lock failed'
	jmp	error_exit_16

.skip:
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
	jz	short .jp1
	dec	ecx
.jp1:	shr	ecx,2			;KB単位 → page 単位
	cmp	ecx,0x40000		;256Kpage max
	jb	.jp2
	mov	ecx,0x40000		;1GB max
.jp2:	mov	[EMB_pages],ecx		;使用可能なページ数として記録

;------------------------------------------------------------------------------
; alloc dos memory
;------------------------------------------------------------------------------
	call	init_dos_malloc

;------------------------------------------------------------------------------
; alloc user call buffer
;------------------------------------------------------------------------------
proc1 alloc_user_call_buffer
	movzx	ax, b [user_cbuf_pages]
	test	ax, ax
	jz	.use_internal_buffer

	mov	cl, 16			;error code: 'User call buufer allocation failed'
	call	dos_malloc_page

	mov	[user_cbuf_ladr], eax	;linear address
	shr	eax, 4
	mov	[user_cbuf_seg16], ax	;dos segment
	jmp	short .skip

.use_internal_buffer:
	mov	eax, [call_buf_adr16]
	mov	ebx, [call_buf_adr32]
	add	ebx, [top_ladr]
	mov	[user_cbuf_adr16], eax	; Seg:Off
	mov	[user_cbuf_ladr],  ebx	; linear address

	; rewrite size
	movzx	ax, [call_buf_sizeKB]
	shr	ax, 2
	mov	[user_cbuf_pages], al

.skip:
;------------------------------------------------------------------------------
; initalize page directory and first page table
;------------------------------------------------------------------------------
proc1 init_page_directory
	mov	ax,  2			;page dir + page table 0
	mov	cl, 13			;error code: 'Page table allocation failed'
	call	dos_malloc_page

	mov	[page_dir_ladr],eax	;page directory linear address
	shr	eax, 4
	mov	[page_dir_seg], ax	;page directory dos segment

	; 8KB zero fill
	push	es
	mov	es, ax			;page dir segment

	xor	eax,eax			;eax = 0
	xor	edi,edi			;es:edi
	mov	ecx,2000h / 4		;loop
	rep	stosd			;zero fill

	mov	ecx, [page_dir_ladr]
	shr	ecx, 12			;byte to page
	mov	ax,0de06h		;VCPI 06h, get phisical address
	int	67h			;edx = page directory phisical address
	mov	[to_PM_CR3],edx		;save

	;///////////////////////////////////////////////////
	;Regist first page table to page directory
	;///////////////////////////////////////////////////
	inc	cx			;first page table linear address
	mov	ax,0de06h		;VCPI 06h, get phisical address
	int	67h			;VCPI call
	mov	  dl,07h		;enable entry
	mov	[es:0],edx		;entry first page table

	pop	es

;------------------------------------------------------------------------------
; alloc additional page table from DOS memory
;------------------------------------------------------------------------------
;	When more than 4MB of extended memory is used,
;	additional page tables are required in DOS memory.
;  拡張メモリが4MB以上使われている時、DOSメモリ内に追加ページテーブルが必要。
;
proc1 alloc_page_table
	mov	eax, [EMB_physi_adr]	; free memory's phisical address
	add	eax, 0fffh		; 4KB Unit
	shr	eax, 22			; to need page tables
	jz	.not_need

	add	[page_tables_in_dos],ax	; count up
	mov	bp, ax			; bp = need tables

	mov	cl, 13			;error code: 'Page table allocation failed'
	call	dos_malloc_page
	mov	ecx, eax		; ecx = linear address
	shr	ecx, 12			; byte to page

	push	es
	push	fs
	mov	fs, [page_dir_seg]
	xor	bx, bx
.loop:
	; cx = target linear adddress/4KB
	mov	ax,0de06h		; get Phisical address
	int	67h			; VCPI call
	mov	dl,07h			; address to table entry
	add	bx, 4
	mov	[fs:bx], edx		; entry to page directory

	; clear page table
	mov	dx, cx
	shl	cx, 12-4		; PAGE to para
	mov	es, cx
	xor	di, di
	mov	cx, 1000h / 4		; 4KB/4
	xor	eax, eax
	rep	stosd

	inc	cx			; for loop
	dec	bp
	jnz	.loop

	pop	fs
	pop	es
.not_need:

;------------------------------------------------------------------------------
; [VCPI] get protected mode interface
;------------------------------------------------------------------------------
proc1 get_VCPI_interface
	push	es

	mov	ax, [page_dir_seg]	;page directory segment
	add	ax, 100h		;page0 table segment
	mov	es, ax
	xor	edi,edi			;es:di = first page table address

	mov	si,[GDT_adr]		;GDT offset
	add	si,VCPI_sel		;ds:si = Descriptor table entries in GDT
	mov	ax,0de01h
	int	67h

	pop	es

	test	ah,ah			;戻り値 check
	jz	.save			;問題なければ jmp

	mov	ah,08			; 'VCPI: Failed to get protected mode interface'
	jmp	error_exit_16

.save:
	mov	[VCPI_entry],ebx
	shl	edi,(12-2)		; di = first unused page table entry in buffer
	mov	[free_liner_adr],edi	;edi = free linear address


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
%if Restore8259A && I8259A_IMR_S
	in	al,I8259A_IMR_S		;8259A スレーブ
	mov	ah,al			;ah へ移動
	in	al,I8259A_IMR_M		;8259A マスタ
	mov	[intr_mask_org],ax	;記憶
%endif


;------------------------------------------------------------------------------
;●ＣＰＵモード切替え準備
;------------------------------------------------------------------------------
proc1 setup_PM_struct
	mov	eax,[top_ladr]		;プログラム先頭リニアアドレス
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

	;mov	w [to_PM_LDTR],LDT_load_sel	;LDTRの値（初期値定義済）
	;mov	w [to_PM_TR]  ,TSS_load_sel	;TRの値（初期値定義済）
	mov	d [to_PM_EIP] ,offset start32	;EIP の値
	;mov	w [to_PM_CS]  ,F386_cs		;CS の値（初期値定義済）


;------------------------------------------------------------------------------
;●GDT 初期設定ルーチン
;------------------------------------------------------------------------------
;GDT 内の LDT / IDT / TSS / DOSメモリ セレクタの設定
;
proc1 setup_LDT_IDT_TSS

	mov	 di,[GDT_adr]	;GDT のオフセット
	mov	ebx,[top_ladr]	;このプログラムの先頭リニアアドレス(bit 31-0)

	;/// Free386用 CS/DS 設定 ///////////////////////////////////

	mov	dl,[top_ladr +2]	;bit 16-23
	mov	ax,0ffffh		;リミット値

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

	mov	[di + LDT_load_sel   + 2],ecx	;ベースアドレス設定
	mov	[di + LDT_sel        + 2],ecx	;
	mov	[di + LDT_load_sel      ],ax	;リミット値設定
	mov	[di + LDT_sel           ],ax	;
	mov	w [di + LDT_load_sel + 5],0082h	;属性設定 (LDT)
	mov	w [di + LDT_sel      + 5],4092h	;属性設定 (Read/Write)

	;/// GDT/IDT アクセス用セレクタの設定 ///////////////////////

	mov	ecx,[GDT_adr]			;GDT オフセット
	mov	edx,[IDT_adr]			;IDT オフセット
	add	ecx,ebx				;先頭アドレス加算
	add	edx,ebx				;  〃
	mov	[di + GDT_sel   + 2],ecx	;ベースアドレス設定
	mov	[di + IDT_sel   + 2],edx	;  〃
	mov	w [di + GDT_sel    ],GDTsize-1	;リミット値設定
	mov	w [di + IDT_sel    ],IDTsize-1	;
	mov	w [di + GDT_sel + 5],4092h	;属性設定 (Read/Write)
	mov	w [di + IDT_sel + 5],4092h	;属性設定 (Read/Write)

	;/// TSS セレクタの設定 /////////////////////////////////////

	mov	ecx,[TSS_adr]			;TSS のオフセット
	add	ecx,ebx				;先頭アドレス加算
	mov	ax,TSSsize -1			;TSS の大きさ -1

	mov	[di + TSS_load_sel   + 2],ecx	;ベースアドレス設定
	mov	[di + TSS_sel        + 2],ecx	;
	mov	[di + TSS_load_sel      ],ax	;リミット値設定
	mov	[di + TSS_sel           ],ax	;
	mov	w [di + TSS_load_sel + 5],0089h	;属性設定 (利用可能/Avail TSS)
	mov	w [di + TSS_sel      + 5],4092h	;属性設定 (Read/Write)

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


;------------------------------------------------------------------------------
;●割り込みテーブル初期設定ルーチン
;------------------------------------------------------------------------------
;	dw	offset %1	;offset  bit 0-15
;	dw	F386_cs		;selctor
;	dw	0ee00h		;属性 (386割り込みゲート) / 特権レベル3
;	dw	00000h		;offset  bit 16-31
proc1 setup_IDT
	mov	 ax,F386_cs	;セレクタ
	shl	eax,16		;上位へ
	mov	edx,0ee00h	;386割り込みゲート / 特権レベル3
	mov	di,[IDT_adr]	;割り込みテーブル先頭

	;/// CPU 内部割り込み設定 /////////////////////////
	mov	ax,offset PM_int_00h	;割り込み #00
	mov	bp,4			;オフセット加算値
	mov	cx,20h			;ループ数 (00-1fh)
	call	write_IDT		;IDT へ書き込み

	;/// DOS割り込み設定 //////////////////////////////
	mov	cx,10h			;20h ～ 2fh
	mov	si,offset DOS_int_list	;DOS 割り込みリスト
	mov	bp, 8

	align	4
.loop1:	mov	ax,[si]			;jmp 先読み出し
	mov	[di  ],eax		;+00h
	mov	[di+4],edx		;+04h
	add	si,byte 2		;次の割り込みリスト項目
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


;------------------------------------------------------------------------------
; Hardware interrupt IDT setup
;------------------------------------------------------------------------------
proc1 setup_hardware_int_IDT

%ifdef USE_VCPI_8259A_API
	mov	ax,0de0ah		;VCPI function  0Ah
	int	67h			;get 8259 interrupt vector

	mov	[vcpi_8259m], bl
	mov	[vcpi_8259s], cl
	mov	si, cx
	shl	bx, 3
	shl	si, 3
%else
	mov	bx, HW_INT_MASTER *8
	mov	si, HW_INT_SLAVE  *8
%endif
	mov	di, [IDT_adr]		;IDT table offset
	add	si, di			;si = slave  start offset
	add	di, bx			;di = master start offset

	mov	bp, 4	; テーブルオフセット加算値

	mov	ax,HW_int_master_table	;割り込みマスタ側 #00
	mov	cx,8			;ループ数
	;mov	di, di			;マスタ側割り込み番号 *8
	call	write_IDT		;IDT へ書き込み

	mov	ax,HW_int_slave_table	;割り込みスレーブ側 #00
	mov	cx,8			;ループ数
	mov	di, si			;スレーブ側割り込み番号 *8
	call	write_IDT		;IDT へ書き込み


;------------------------------------------------------------------------------
;●hook int 24h
;------------------------------------------------------------------------------
proc1 setup_int_24h

	mov	ax, 3524h		; read int 24h
	int	21h
	mov	[DOS_int24h_adr], bx
	mov	[DOS_int24h_seg], es

	mov	dx, offset hook_int_24h
	mov	ax, 2524h		; set int 24h
	int	21h

;------------------------------------------------------------------------------
;●ＣＰＵモード切替え
;------------------------------------------------------------------------------
proc1 cpu_mode_change

	mov	ax,0de0ch		;VCPI function  0Ch
	mov	esi,[top_ladr]		;プログラム先頭リニアアドレス
	add	esi,offset to_PM_data	;切替え用構造体アドレス
	mov	[to_PM_data_ladr],esi	;上記リニアアドレス記録

	int	67h			;プロテクトモードの start32 へ

	mov	ah, 09			;'VCPI: Failed to change CPU to protected mode'
	jmp	error_exit_16


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
	add	ax, bp			;次の割り込みアドレスへ
	add	di, 8			;セレクタオフセット更新
	loop	write_IDT
	ret


;------------------------------------------------------------------------------
;●確保した拡張メモリの開放
;------------------------------------------------------------------------------
	align	4
free_EMB:
	mov	dx,[EMB_handle]	;dx = EMBハンドル
	test	dx,dx		;ハンドルの値確認
	jz	.ret		;0 ならば ret
	mov	w [EMB_handle], 0

	mov	ah,0dh		;EMB のロック解除
	XMS_function

	mov	ah,0ah		;EMB の開放
	XMS_function
	test	ax,ax		;ax = 0 ?
	jnz	.ret		;non 0 なら jmp

	PRINT16	err_xms_free	;「メモリ開放失敗」
.ret:
	ret


;------------------------------------------------------------------------------
; hook for int 24
;------------------------------------------------------------------------------
proc2 hook_int_24h
	pushf
	call	far [cs:DOS_int24h_adr]

	cmp	al,02h
	jne	.ret
	int	23h		; Force end program
.ret:
	iret
	; 本来 al=2 のときは、CTRL-C ルーチン（int 23h）が呼ばれるはずだが、
	; なぜか呼ばれない（DOS6にて確認）ので、
	; あまり良い方法ではないが強制的に呼んでいる。

;##############################################################################
;==============================================================================
;■プログラムの終了 (16 bit)
;==============================================================================
proc2 exit_16
	;////////////////////////////////////////////////////////////
	;/// 割り込みマスク復元 /////////////////////////////////////
	%if Restore8259A && I8259A_IMR_S
		mov	ax,[intr_mask_org]	;復元情報
		out	I8259A_IMR_M, al	;マスタ側
		mov	al,ah			;
		out	I8259A_IMR_S, al	;スレーブ側
	%endif

	;///////////////////////////////
	;各機種固有の終了処理
	;///////////////////////////////
	%if TOWNS
		call	exit_TOWNS_16
	%elif PC_98
		call	exit_PC98_16
	%elif PC_AT
		call	exit_AT_16
	%endif

	;///////////////////////////////
	;メモリ解放
	;///////////////////////////////
	sti
	call	free_EMB		;確保したメモリの開放

	mov	ax,[err_level]		;AH = Free386 ERR / AL = Program ERR
	test	ah,ah			;check
	jnz	error_exit_16		;non 0 ならエラー終了

	mov	ah,4ch
	int	21h			;正常終了


;------------------------------------------------------------------------------
;error exit
;------------------------------------------------------------------------------
; in	ah = Free386's internal error code
;
proc2 error_exit_16
	;
	; search error message
	;
	test	ah, ah
	jz	.exit			;ah=0, no error message

	mov	bx, err_msg_table
.loop0:
	dec	ah
	jz	.found

	mov	cx, 256			;safety
.loop1:
	mov	al, [bx]
	inc	bx
	cmp	al, '$'
	je	.loop0
	dec	cx
	jnz	.loop1
	;
	; safety
	;
	mov	bx, err_00
.found:
	cmp	b [bx], 0		;output only when verbose flag
	jnz	.print
	cmp	b [verbose], 0
	jz	.exit

.print:
	PRINT16	err_head
	mov	dx,bx
	mov	ah,09h			;output error message
	int	21h
.exit:
	call	free_EMB
	mov	al, F386ERR
	mov	ah, 4ch
	int	21h			;end


;******************************************************************************
; 32bit mode code
;******************************************************************************
seg32	text32 class=CODE align=4 use32

%include	"f386prot.asm"

;******************************************************************************
; DATA
;******************************************************************************
segdata	data class=DATA align=4

%include	"f386data.asm"

;******************************************************************************
;heap
;******************************************************************************
segheap	heap class=DATA align=16
end_adr:
	;
	; Below is the heap memory area.
	;
;******************************************************************************
;******************************************************************************
