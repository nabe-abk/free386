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
proc4 int_21h_30h
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
	mov	ecx, 'IPCV'			;="VCPI", に "DPMI" がある。
	cmp	b cs:[use_vcpi], 0
	jnz	.skip
	mov	ecx, 'SOD'			;="DOS\0", 00444F53h
.skip:	
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
proc1 int_21h_00h
	xor	al,al		;リターンコード = 0 / DOS互換
proc4 int_21h_4ch
	add	esp,12		;スタック除去
	jmp	exit_32		;DOS-Extender 終了処理


;------------------------------------------------------------------------------
; create selector in LDT
;------------------------------------------------------------------------------
; in	ebx = alloc pages
; ret	 cy = 0	success
;		AX  = created selector
;	 cy = 1	fail.
;		AX  = 8 not enough selector or memory
;		ebx = free pages
;
proc4 int_21h_48h
	push	esi
	push	edi
	push	ecx
	push	ds

	push	F386_ds
	pop	ds

	call	get_free_linear_adr	;esi = linear address
	mov	ecx, ebx		;ecx = alloc pages
	call	allocate_RAM
	jc	.fail	; use esi for get_max_alloc in .fail

	call	search_free_LDTsel	;eax = selector
	jc	.fail	; use esi for get_max_alloc in .fail

	mov	edi, [work_adr]
	mov	[edi  ], esi		;base
	mov	[edi+4], ebx		;size (pages)
	mov	w [edi+8],1200h		;R/W 386, DPL=0, AVL=1
					;AVL bit is only FreeRAM selector
	test	ebx, ebx
	jz	.zero_selector

	call	make_selector_4k	;eax=selector, [edi]=options
	jmp	.end

.zero_selector:		; pages = 0
	mov	[edi+4], ebx		;0
	call	make_selector		;eax=selector, [edi]=options

.end:
	call	regist_managed_LDTsel	;ax=selector

	pop	ds
	pop	ecx
	pop	edi
	pop	esi
	clear_cy
	iret


.fail:	call	get_max_alloc_pages	;eax = max allocatable pages
	mov	ebx,eax			;ebx = eax
	mov	eax,8

	pop	ds
	pop	ecx
	pop	edi
	pop	esi
	set_cy
	iret


;------------------------------------------------------------------------------
; Free LDT memory
;------------------------------------------------------------------------------
; IN	es = free selector
;
proc4 int_21h_49h
	pusha
	push	ds

	push	F386_ds
	pop	ds

	mov	eax, es			;eax = selector
	mov	ebp, es			;ebp = selector (save)
	test	 al, 04h		;LDT?
	jz	.error

	call	remove_managed_LDTsel	;remove from list, eax=selector
	jc	.error			;not listed

	call	get_selector_base_ladr	;ebx = info address
					;esi = base linear address
	test	esi, 0fffh		;bit 0-11
	jnz	.error

	lsl	ecx, eax		;ecx = selector limit
	mov	edi, [ebx+4]		;edi = selector info 4-7 byte

	;clear LDT
	xor	eax, eax
	mov	 es, eax		;clear es
	mov	[ebx  ], eax		;clear selector info
	mov	[ebx+4], eax		;

	;check size
	test	ecx, ecx		;limit = 0?
	jz	.skip
	shr	ecx, 12			;pages limit
	inc	ecx			;edx = selector size (pages)

	;free RAM
	bt	edi, 20			;AVL bit, allocate_RAM only selector
	jnc	.skip
	;mov	ecx, ecx		;ecx = free pages
	;mov	esi, esi		;esi = start linear address
	call	free_RAM
.skip:

	pop	ds
	popa
	clear_cy
	iret

.error:
	pop	ds
	popa
	set_cy
	iret


;------------------------------------------------------------------------------
; Resize selector	AH=4ah
;------------------------------------------------------------------------------
; IN	 es = selector
;	ebx = new page size
; Ret	 Cy = 0 Success
;	 Cy = 1 Fail
;		eax = 8 not enough memory
;		eax = 9 selector is void
;		ebx = free pages
;
proc4 int_21h_4ah
	start_sdiff
	pusha_x
	push_x	ds
	push_x	fs

	push	F386_ds
	pop	ds
	push	ALLMEM_sel
	pop	fs

	mov	ebp, ebx		;ebp = new size [page]
	mov	eax, es			;eax = selector
	call	search_managed_LDTsel	;search from list, eax=selector
	jc	.selector_error		;not found

	call	get_selector_base_ladr	;ebx = selector info
					;esi = selector base (keep until last)
	test	b [ebx+6], 80h		;check AVL, AVL is mapped only FreeRAM.
	jc	.selector_error		;not set is  found

	test	esi, 0fffh		;base address is aligned page?
	jnz	.selector_error

	lsl	edx, eax		;edi = limit [byte]
	test	edx, edx
	jz	.skip
	shr	edx, 12			;edx = limit [page]
	inc	edx			;edx = size  [page]
.skip:
	mov	edi, edx		;edi = size  [page]
	shl	edi, 12			;edi = size  [byte] (4K unit)
	add	edi, esi		;edi = linear address of selector end

	cmp	ebp, edx		;new - current
	je	.success		;same
	jb	.decrease		;ebp < edx

	;---------------------------------------------------
	; increase memory
	;---------------------------------------------------
	push	esi
	mov	ecx, ebp		;ecx = new pages
	sub	ecx, edx		;ecx = new allocate pages
	mov	esi, edi		;esi = allocate linear address
	call	allocate_RAM
	pop	esi
	jc	.fail		;use esi in get_max_alloc_pages()
	jmp	.rewrite_limit

	;---------------------------------------------------
	; decrease memory
	;---------------------------------------------------
.decrease:
	push	esi
	mov	ecx, edx		;ecx = current pages
	sub	ecx, ebp		;ecx = free pages

	mov	esi, edi		;esi = current selector end
	mov	eax, ecx		;eax = free pages
	shl	eax, 12			;eax = decrease memory size
	sub	esi, eax		;esi = new selector end

	call	free_RAM		;ecx = free pages, esi = start address
	pop	esi
	jc	.fail		;use esi in get_max_alloc_pages()

	;---------------------------------------------------
	; rewrite selector limit
	;---------------------------------------------------
.rewrite_limit:
	mov	ecx, ebp
	; IN	ecx = new pages
	;	esi = selector base address
	call	rewrite_managed_LDTsels_limit

	call	reload_all_selector

.success:
	clc
.exit:	pop	fs	; not use "pop_x" for keep .sdiff
	pop	ds
	popa
	iret_save_cy

.selector_error:
	mov	d [esp + .sdiff - 4], 9		;stack eax = 9
	stc
	jmp	.exit

.fail:	call	get_max_alloc_pages		;esi use!
	mov	d [esp + .sdiff - 4], 8		;stack eax = 9
	mov	d [esp + .sdiff -16], eax	;stack ebx = max alloc
	stc
	jmp	.exit

;------------------------------------------------------------------------------
; map phisical memory at end of selector
;------------------------------------------------------------------------------
; IN	 AX = 250ah
;	 es = target selector
;	ebx = phisical memory address
;	ecx = mapping pages
;
proc4 DOSX_fn_250ah
	push	ds
	push	esi
	push	edi
	push	ebp
	push	edx
	push	ecx	;ecx is stack+4 top
	push	ebx	;ebx is stack   top

	push	F386_ds
	pop	ds

	mov	ebx,es		;ebx = selector
	test	bl, 04
	jz	.fail0		;not support GDT

	callint	DOSX_fn_2508h	;get selector base address
	jc	.fail0		;ecx = base

	lsl	ebx, ebx	;ebx = limit
	test	ebx, ebx
	jz	.skip
	inc	ebx		;ebx = size
.skip:
	mov	edi, ebx	;edi = size
	mov	ebp, ebx	;ebp = size (save old size)
	add	edi, ecx	;ecx = selector limit linear address +1

	test	edi, 0fffh	;UNIT is 4K?
	jnz	.fail0

	mov	esi, ecx	;esi = map linear address
	mov	edx, [esp]	;edx = map phisical address
	mov	ecx, [esp+4]	;ecx = map pages
	test	ecx, ecx
	jz	.end		;if ecx=0

	call	set_physical_memory
	jc	.fail1		;not enough page table

	mov	eax, ebp	;eax = old size
	shr	eax, 12
	mov	eax, ecx	;eax = new size/4K
	dec	eax		;eax = limit

	;-------------------------------------------------------------
	; save to LDT
	;-------------------------------------------------------------
	mov	ecx, es
	and	 cl, 0f8h	;0ch -> 08h
	mov	ebx, [LDT_adr]
	add	ebx, ecx	;ebx = selector's descriptor pointer

	mov	[ebx], ax	;limit  bit0-15
	mov	dl, [ebx+6]
	shr	eax, 16		;eax = limit16-19
	and	dl, 70h - 10h	;save original selector info, clear AVL(bit4)
				;AVL bit is only FreeRAM, 250Ah is void this
	and	al, 0fh		;limit bit16-19
	or	al, dl		;mix
	or	al, 80h		;Force G bit
	mov	[ebx+6], al	;

	call	reload_all_selector

.end:
	mov	eax, ebp	;new mapping offset of selector
	clc
.exit:
	pop	ebx
	pop	ecx
	pop	edx
	pop	ebp
	pop	edi
	pop	esi
	pop	ds
	iret_save_cy

.fail0:	mov	eax,9		;invalid selector
	stc
	jmp	.exit

.fail1:	mov	eax,8		;not enough page table
	stc
	jmp	.exit


;******************************************************************************
; DOS-Extender functions  AH=25h
;******************************************************************************
proc4 DOS_Extender_fn
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
; Unknown function
;------------------------------------------------------------------------------
proc4 DOSX_unknown
	mov	eax,0a5a5a5a5h		;DOS-Extender specification
	set_cy
	iret

;------------------------------------------------------------------------------
;・V86←→Protect データ構造体のリセット  AX=2501h
;------------------------------------------------------------------------------
proc4 DOSX_fn_2501h
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
proc4 DOSX_fn_2502h
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
proc4 DOSX_fn_2503h
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
proc4 DOSX_fn_2504h
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
proc4 DOSX_fn_2505h
	call	set_V86_vector
	clear_cy
	iret

proc4 set_V86_vector
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
proc4 DOSX_fn_2506h
	push	ebx
	push	ecx
	push	esi
	push	ds

	push	F386_ds
	pop	ds

	movzx	ecx,cl

	mov	ebx,[V86_cs]		;V86 ベクタ CS
	shl	ebx,16			;上位へ
	mov	esi,[V86int_table_adr]	;int 0    の hook ルーチンアドレス
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
proc4 DOSX_fn_2507h
	;call	set_V86_vector
	;jmp	DOSX_fn_2504h	;プロテクトモードの割り込み設定

		;↓

	push	offset DOSX_fn_2504h
	jmp	set_V86_vector

;------------------------------------------------------------------------------
; get selecot base address
;------------------------------------------------------------------------------
; IN	bx = selector
; Ret	Cy = 0 Sucess
;		ecx = selector base linear address
;	Cy = 1 Fail
;
proc4 DOSX_fn_2508h
	verr	bx
	jnz	.void

	push	eax
	push	ebx
	push	esi

	movzx	eax, bx			;eax = selector
	call	get_selector_base_ladr	;ebx = info adr, esi = base adr
	mov	ecx, esi		;ecx = base adr

	pop	esi
	pop	ebx
	pop	eax
	clear_cy
	iret

.void:
	mov	eax, 9			;invalid selector
	set_cy
	iret

;------------------------------------------------------------------------------
; convert linear address to phisical address
;------------------------------------------------------------------------------
; IN	ebx = linear address
; Ret	 Cy = 0 Success
;		ecx = phisical address
;	 Cy = 1 Fail
;
proc4 DOSX_fn_2509h
	call	get_phisical_address
	iret_save_cy

;------------------------------------------------------------------------------
; map phisical memory at end of selector
;------------------------------------------------------------------------------
; written in upper part (next of AH=4ah)
;
;------------------------------------------------------------------------------
;・ハードウェア割り込みベクタの取得　AX=250ch
;------------------------------------------------------------------------------
proc4 DOSX_fn_250ch

	%ifdef USE_VCPI_8259A_API
		mov	ax, [cs:vcpi_8259m]
	%else
		mov	al, HW_INT_MASTER
		mov	ah, HW_INT_SLAVE
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
proc4 DOSX_fn_250dh
	mov	ebx, d [cs:user_cbuf_adr16]
	movzx	ecx, b [cs:user_cbuf_pages]
	shl	ecx, 12				; page to byte

	mov	eax, DOSMEM_sel
	mov	 es, ax
	mov	edx, d [cs:user_cbuf_ladr]

	mov	 ax, [cs:V86_cs]
	shl	eax, 16
	mov	 ax, offset call32_from_V86

	clear_cy
	iret

;------------------------------------------------------------------------------
; convert 32bit address to dos address
;------------------------------------------------------------------------------
; IN 	es:ebx	address
;	ecx	check size
;
; Ret	Cy = 0 Success
;		ecx = DOS seg:off address
;	Cy = 1 Fail
;		ecx = linear address
;
proc4 DOSX_fn_250fh
	pusha

	mov	ebp, ebx		;ebp = address
	mov	edx, ecx		;edx = size

	mov	eax, es			;eax = selector, ds = any
	call	get_selector_base_ladr	;ebx = info adr, esi = base adr
	add	esi, ebp		;esi = target linear address (save)

	mov	ebx, esi		;ebx = linear address
	call	get_phisical_address	;ecx = phisical address
	mov	edi, ecx		;edi = target phisical address (save)
	cmp	ecx, 100000h
	jae	.fail			;ecx >= 1MB

	mov	eax, esi		;eax = linear address
	and	eax, 0fffh		;bit 0-11
	;mov	ebx, esi		;ebx = linear address, current
	mov	ebp, ecx		;ebp = phisical address
	sub	ebp, eax		;phisical adr -= bit0-11 (align 4K)
	sub	ebx, eax		;linear adr   -= bit0-11 (align 4K)
	add	edx, eax		;linear size  += bit0-11
	jc	.fail

	mov	eax, 1000h		;eax = const 4K
.loop:
	sub	edx, eax		;edx -= 1000h
	jbe	.success		;checked for size

	add	ebx, eax		;linear   adr += 1000h
	add	ebp, eax		;phisical adr += 1000h
	call	get_phisical_address	;ecx = phisical address
	cmp	ecx, 100000h
	jae	.fail			;ecx >= 1MB
	cmp	ecx, ebp		;continus?
	jne	.fail
	jmp	.loop

.success:
	; conver to seg:off
	mov	eax, edi		;eax = phisical address
	mov	ecx, edi		;ecx = phisical address
	shl	ecx, 12			;ecx bit16-31 = seg (adr bit4-20)
	and	 ax, 00fh		;eax = adr bit0-3
	mov	 cx, ax			;ecx bit0-15  = off (adr bit0-3)

	mov	[esp + 18h], ecx	;ecx = seg:off
	popa
	clear_cy
	iret

.fail:	mov	[esp + 18h], esi	;ecx = esi = linear address
	popa
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
%define	COPY_STACK_MAX_WORDS	((SW_stack_size - 40h)/2)

proc4 DOSX_fn_250eh
	start_sdiff
	pushf_x
	cmp	ecx, COPY_STACK_MAX_WORDS
	ja	.fail

	push_x	eax
	push_x	ecx
	push_x	ds

	push	F386_ds
	pop	ds

	lea	eax, [esp + .sdiff + 0ch]	; copy stack offset
	mov	[cv86_copy_stack], eax
	shl	ecx, 1				; ecx is copy word count
	mov	[cv86_copy_size],  ecx

	pop_x	ds
	pop_x	ecx
	pop_x	eax
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
proc4 DOSX_fn_2510h
	call_DumpDsEdx	18h		; dump, if set DUMP_DS_EDX

	start_sdiff
	push_x	es
	pushf_x
	cmp	ecx, COPY_STACK_MAX_WORDS
	ja	.fail

	push	F386_ds
	pop	es

	;--------------------------------------------------
	; check copy stack size
	;--------------------------------------------------
	push_x	ecx

	lea	eax, [esp + .sdiff + 0ch]
	mov	es:[cv86_copy_stack], eax	; copy stack top
	shl	ecx, 1				; ecx is copy word count
	mov	es:[cv86_copy_size],  ecx	; copy bytes

	pop_x	ecx
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
	mov	ebx, [edx + 0ch]

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
proc4 DOSX_fn_2511h
	call_DumpDsEdx	12h		; dump, if set DUMP_DS_EDX

	push	es
	push	edx

	push	F386_ds
	pop	es

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
proc4 DOSX_fn_2513h
	push	ds
	push	edx
	push	ecx
	push	ebx
	push	eax	;戻り値を直接書き込むので、最後の積む

	push	F386_ds
	pop	ds

	verr	bx
	jnz	.fail

	call	search_free_LDTsel	;空きセレクタ検索
	jc	.fail

	call	regist_managed_LDTsel	;regist eax

	mov	[esp], eax	;コピー先セレクタ（戻り値記録）

	push	ebx
	call	get_selector_info_adr	;LDT内アドレスに変換
	mov	edx,ebx			;edx = コピー先アドレス
	pop	eax			;eax = コピー元セレクタ
	call	get_selector_info_adr	;ebx = コピー元アドレス

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

	pop	eax		;load eax
	pop	ebx
	pop	ecx
	pop	edx
	pop	ds
	clear_cy
	iret

.fail:	mov	eax,8
.ret:	pop	ebx	; skip eax
	pop	ebx
	pop	ecx
	pop	edx
	pop	ds
	set_cy
	iret

.void:
	mov	eax,9	;invalid selector
	jmp	short .ret


;------------------------------------------------------------------------------
;・セグメント属性の変更　AX=2514h
;------------------------------------------------------------------------------
proc4 DOSX_fn_2514h
	push	ecx
	push	ebx
	push	eax
	push	ds

	verr	bx
	jnz	.void

	push	F386_ds
	pop	ds

	movzx	eax,bx			;eax = セレクタ
	call	get_selector_info_adr	;ebx = アドレス

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
proc4 DOSX_fn_2515h
	push	ebx
	push	eax

	verr	bx
	jnz	.void

	movzx	eax, bx			;eax = セレクタ
	call	get_selector_info_adr	;ebx = アドレス

	mov	cx, cs:[ebx+5]		;USE / Type ロード

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
proc4 DOSX_fn_2517h
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
proc4 DOSX_fn_25c0h
	mov	ah,48h
	jmp	call_V86_int21_iret

;------------------------------------------------------------------------------
;・DOSメモリブロックの解放　AX=25c1h
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
;・MS-DOSメモリブロックのサイズ変更　AX=25c2h
;------------------------------------------------------------------------------
proc4 DOSX_fn_25c1h
	push	eax
	mov	ah,49h		; free memory block
	jmp	short DOSX_fn_25c2h.step

proc4 DOSX_fn_25c2h		; resize memory block
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
