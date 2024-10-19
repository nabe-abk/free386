;******************************************************************************
;　Segment and memory routine	for Free386
;******************************************************************************
;[TAB=8]
;
;
%include	"macro.inc"
%include	"start.inc"
%include	"f386def.inc"
%include	"free386.inc"
%include	"memory.inc"

;******************************************************************************
seg32	text32 class=CODE align=4 use32
;******************************************************************************
; IN	eax = selector
;	[edi]	dword	base offset
;	[edi+4]	dword	size (byte or page)
;	[edi+8]	byte	DPL (0-3)
;	[edi+9]	byte	selector type (0-15), bit4 = AVL bit
;
; supprot only 32bit meomory selector.
;
proc4 make_selector
	push	edx

	xor	edx, edx
	call	do_make_selector

	pop	edx
	ret

proc4 make_selector_4k
	push	edx

	mov	edx, 80_0000h	;G bit=1, size unit is 4K
	call	do_make_selector

	pop	edx
	ret

proc4 do_make_selector
	push	eax
	push	ebx
	push	ecx

	mov	ebx, [GDT_adr]
	test	al, 4		;check bit 2
	jz	.is_GDT	 	; 0 is GDT
	mov	ebx, [LDT_adr]
.is_GDT:
	and	eax, 0fff8h
	add	ebx, eax	;ebx = target selector pointer

	mov	eax, [edi+4]	;eax = size
	test	eax, eax	;size check
	jnz	.skip		; is non zero
	xor	edx, edx	;G bit clear
	inc	eax		;eax = 1
.skip:	dec	eax		;eax = limit = size -1

	mov	[ebx], ax	;save bit0-15
	and	eax,0f0000h	;eax = limit bit16-19

	mov	ecx, [edi]	;ecx = base
	mov	[ebx+2], cx	;base bit0-15
	mov	al, [edi+2]	;eax bit0-7 <= base bit16-23
	and	ecx, 0ff000000h	;base bit24～31
	or	eax, ecx	;eax bit24-31 <= base bit24-31

	mov	cx, [edi+8]	;cl=DPL, ch=type
	bt	ecx,12		;cy=AVL
	jnc	.skip2
	bts	eax,20		;set AVL bit
.skip2:
	and	ch, 0fh		;type mask
	and	cl, 3		;DPL
	shl	cl, 5		;bit5-6 = DPL
	or	cl, ch		;cl bit0-3=type, bit5-6=DPL
	mov	ah, cl		;eax bit8-11=type, bit13-14=DPL

	or	ah, 90h		;eax bit12=DT=1(code or data)
				;eax bit15=Present=1
	bts	eax, 22		;eax bit22=Operation size=1(32bit seg)
	or	eax, edx	;mix G bit
	mov	[ebx+4], eax	;save

	pop	ecx
	pop	ebx
	pop	eax
	ret

;------------------------------------------------------------------------------
; map memory with phisical address
;------------------------------------------------------------------------------
; IN	esi = linear address   (4KB Unit)
;	edx = phisical address (4KB Unit)
;	ecx = pages
;
; Ret	Cy = 0 success
;	Cy = 1 fail
;
proc4 set_physical_memory
	pusha
	push	es

	push	ALLMEM_sel
	pop	es

	test	ecx,ecx
	jz	.success
					;esi = linear address, ecx = pages
	call	prepare_map_linear_adr	;allocate page table
	jc	.not_enough_memory

	;---------------------------------------------------
	; prepare allocate
	;---------------------------------------------------
	mov	ebx, esi
	shr	ebx, 10
	and	ebx, 0ffch		; page table offset

	shr	esi, 20
	and	esi, 0ffch		; esi = offset of page directory
	add	esi, [page_dir_ladr]	; esi = page directory entry
	mov	eax, es:[esi]		; load
	test	al, 1			; P bit
	jz	.error
	and	eax, 0fffff000h		; eax = page table linear address
	add	ebx, eax		; ebx = page table entry

	;---------------------------------------------------
	; allocate loop
	;---------------------------------------------------
	or	dl, 7			;edx = page table entry
	mov	ebp,1000h		;const
.loop:
	mov	es:[ebx], edx		;page entry
	add	edx, ebp		;edx = next phisical address

	; counter check
	dec	ecx
	jz	.success

	; next page table address
	add	ebx, 4
	test	ebx, 0fffh
	jnz	.loop

	; load next page table entry
	add	esi, 4
	mov	ebx, es:[esi]		; load
	test	bl, 1			; P bit
	jz	.error
	and	ebx, 0fffff000h		; ebx = page table linear address
	jmp	.loop

.success:
	clc
.exit:
	pop	es
	popa
	ret

.error:
.not_enough_memory:
	stc
	jmp	.exit

;------------------------------------------------------------------------------
; create selector with memory mapping table
;------------------------------------------------------------------------------
; IN	ds:[ebx]	memory mapping table
;
proc4 map_memory
	mov	eax,[ebx]		;作成するメモリセレクタ
	test	eax,eax			;値 check
	jz	.exit			;0 なら終了

	mov	edx,[ebx + 04h]		;edx = 張りつける物理アドレス
	mov	ecx,[ebx + 08h]		;ecx = 張りつけるページ数
	mov	esi,edx			;esi = 張りつけ先リニアアドレス
	call	set_physical_memory	;物理メモリの配置
	jc	.error

	lea	edi,[ebx + 4]		;セレクタ作成構造体
	call	make_selector_4k	;eax=作成するセレクタ  edi=構造体

	add	ebx,byte 10h		;アドレス更新
	jmp	short map_memory	;ループ

.exit:	clc
	ret

.error:
	stc
	ret

;------------------------------------------------------------------------------
; make alias selector
;------------------------------------------------------------------------------
; IN	ebx	original selector
;	ecx	alias selector
;	al	DPL, selector level(0-3)
;	ah	selector type (0-15)
;
proc4 make_alias
	push	edx
	push	ecx
	push	ebx
	push	eax	; keep top

	mov	eax, ebx		;eax = from
	call	get_selector_info_adr
	mov	edx, ebx		;edx = from address
	mov	eax, ecx		;eax = to
	call	get_selector_info_adr	;ebx = to address

	mov	eax, [edx]		;copy
	mov	[ebx],eax		;copy

	;ah=type, al=level
	mov	eax, [esp]

	mov	ecx, [edx+4]		;load
	and	ch,90h			;bit 7,4
	shl	al,5			;level bit5-6
	or	ch, al			;set level
	or	ch, ah			;set type
	mov	[ebx+4], ecx		;save

	pop	eax
	pop	ebx
	pop	ecx
	pop	edx
	ret

;------------------------------------------------------------------------------
; make alias selector by table
;------------------------------------------------------------------------------
; IN	ds:[esi]	alias infomation table
;
proc4 make_aliases
	push	eax
	push	ebx
	push	ecx
	push	esi
.loop:
	mov	ebx,[esi  ]		;copy from
	mov	ecx,[esi+4]		;copy to
	mov	eax,[esi+8]		;selector type

	test	ebx,ebx
	jz	.exit
	call	make_alias		;別名作成

	add	esi, 0ch
	jmp	.loop
.exit:
	pop	esi
	pop	ecx
	pop	ebx
	pop	eax
	ret

;##############################################################################
; free memory management
;##############################################################################
;------------------------------------------------------------------------------
; regist free memory block
;------------------------------------------------------------------------------
; IN	ebx	free memory phisical address
;	edx	free memory pages
;
proc4 regist_free_memory
	pusha
	push	es

	test	edx, edx
	jz	.ret

	les	edi, [freeRAM_bm_ladr]
	test	edi, edi
	jnz	.store_free_memory

	call	.init_bitmap
	jc	.ret
	test	edx, edx
	jz	.ret

proc1 .store_free_memory
	add	[freeRAM_pages], edx
	shr	ebx, 12			; unit pages
	mov	ecx, edx
.lp:
	bts	es:[edi], ebx
	inc	ebx
	loop	.lp

.ret:
	pop	es
	popa
	ret


proc4 .init_bitmap
	mov	eax, [all_mem_pages]
	shr	eax, 4			; eax = total bitmap size (byte)

	add	eax, 0fffh		;
	shr	eax, 12			; bitmap need pages

	sub	edx, eax		; pages - bitmap pages
	jb	.init_error

	; regist bitmap
	mov	[freeRAM_bm_ladr], ebx
	shl	eax, 12			; bytes
	mov	[freeRAM_bm_size], eax
	add	ebx, eax		; update ebx

	; clear bitmap
	les	edi, [freeRAM_bm_ladr]
	push	edi
	mov	ecx, eax
	shr	ecx, 2
	xor	eax, eax
	rep	stosd
	pop	edi

	clc
	ret

.init_error:
	stc
	ret

;------------------------------------------------------------------------------
; allocate phisical RAM
;------------------------------------------------------------------------------
; IN	ecx = allocation pages
;	esi = allocate to linear address
;
; Ret	Cy = 0 success
;	Cy = 1 fail
;
proc4 allocate_RAM
	pusha
	push	es

	push	ALLMEM_sel
	pop	es

	;---------------------------------------------------
	; check
	;---------------------------------------------------
	test	ecx, ecx
	jz	.success

	call	get_max_alloc_pages	;eax = maximum allcatable pages
	cmp	eax, ecx
	jb	.not_enough_memory

	call	prepare_map_linear_adr	;allocate page tables
	jc	.not_enough_memory

	;---------------------------------------------------
	; prepare allocate
	;---------------------------------------------------
	sub	[freeRAM_pages], ecx

	mov	ebx, esi
	shr	ebx, 10
	and	ebx, 0ffch		; page table offset

	shr	esi, 20
	and	esi, 0ffch		; esi = offset of page directory
	add	esi, [page_dir_ladr]	; esi = page directory entry
	mov	eax, es:[esi]		; load
	test	al, 1			; P bit
	jz	.error
	and	eax, 0fffff000h		; eax = page table linear address
	add	ebx, eax		; ebx = page table entry

	;---------------------------------------------------
	; prepare allocate loop
	;---------------------------------------------------
	mov	edi, [freeRAM_bm_ladr]	;edi - free RAM bitmap
	mov	 dl, [desc_memory_map]	;descending extended memory mapping

	;
	; start of zero zone skip
	;
	xor	ebp, ebp
	xor	eax, eax
.first_skip_loop:
	cmp	es:[edi+ebp], eax
	jnz	.found_non_zero
	add	ebp, 4
	jmp	.first_skip_loop

.found_non_zero:
	shl	ebp, 3			;*8
	jz	.outloop
	dec	ebp			;need for inc ebp

	;---------------------------------------------------
	; allocate loop
	;---------------------------------------------------
.outloop:
	test	dl, dl
	jz	.loop

	; descending extended memory mapping
	cmp	ebp, 0ffh		;ebp+1 is dos memory?
	jb	.loop

	xor	dl, dl			;clear flag
	mov	b [.loop], 4dh		;rewrite "inc ebp" to "dec ebp"
	mov	ebp, [freeRAM_bm_size]	;bitmap size
	shl	ebp, 3			;*8 (byte to bits)

.loop:
	inc	ebp			;opcode=45h
	btr	es:[edi], ebp
	jnc	.loop

	; found free memory
	mov	eax, ebp
	shl	eax, 12			;eax = free RAM address
	or	 al, 7			;page table entry bits
	mov	es:[ebx], eax		;entry

	; counter check
	dec	ecx
	jz	.success

	; next page table address
	add	ebx, 4
	test	ebx, 0fffh
	jnz	.outloop

	; load next page table entry
	add	esi, 4
	mov	ebx, es:[esi]		; load
	test	bl, 1			; P bit
	jz	.error
	and	ebx, 0fffff000h		; ebx = page table linear address
	jmp	.outloop

.success:
	clc		;キャリークリア
.exit:
	pop	es
	popa
	ret

.error:
.not_enough_memory:
	stc
	jmp	short .exit

;------------------------------------------------------------------------------
; free phisical RAM
;------------------------------------------------------------------------------
; IN	ecx = free pages
;	esi = start linear address
;
; Ret	Cy = 0 success
;	Cy = 1 fail
;
proc4 free_RAM
	pusha
	push	es

	push	ALLMEM_sel
	pop	es

	test	ecx, ecx
	jz	.success

	mov	ebx, esi
	shr	ebx, 10
	and	ebx, 0ffch		; page table offset

	shr	esi, 20
	and	esi, 0ffch		; esi = offset of page directory
	add	esi, [page_dir_ladr]	; esi = page directory entry
	mov	eax, es:[esi]		; load
	test	al, 1			; P bit
	jz	.error
	and	eax, 0fffff000h		; eax = page table linear address
	add	ebx, eax		; ebx = page table entry

	;---------------------------------------------------
	; allocate loop
	;---------------------------------------------------
	mov	edi, [freeRAM_bm_ladr]	;edi - free RAM bitmap
	xor	edx, edx		;edx = collection counter
	xor	ebp, ebp		;ebp = zero
.loop:
	mov	eax, es:[ebx]		;load page table entry
	test	 al, 1			;check P bit
	jz	.skip

	mov	es:[ebx], ebp		;clear page table

	;collection phisical memory
	shr	eax, 12			;eax = phisical page number
	bts	es:[edi], eax		;set free RAM bitmap flag
	inc	edx			;collection counter
.skip:
	; counter check
	dec	ecx
	jz	.loop_end

	; next page table address
	add	ebx, 4
	test	ebx, 0fffh
	jnz	.loop

	; load next page table entry
	add	esi, 4
	mov	ebx, es:[esi]		; load
	test	bl, 1			; P bit
	jz	.error
	and	ebx, 0fffff000h		; ebx = page table linear address
	jmp	.loop

.loop_end:
	add	[freeRAM_pages], edx
	mov	eax, cr3
	mov	cr3, eax		; page cache clear

.success:
	clc
.exit:
	pop	es
	popa
	ret

.error:
	stc
	jmp	.exit

;------------------------------------------------------------------------------
; allocate page table for linear address mapping
;------------------------------------------------------------------------------
; IN	ecx = mapping pages
;	esi = linear address
;
; Ret	Cy = 0 success
;	Cy = 1 fail
;
proc4 prepare_map_linear_adr
	push	ecx
	push	esi

.loop:
	call	allocate_page_table
	jc	.exit		; error

	add	esi, 400000h	; one table is 400000h offset width
	sub	ecx, 1024	; one table is 1024 entry
	jae	.loop

	; start: esi = 100000h, ecx = 600h
	;  next: esi = 500000h, ecx = 200h
	;  exit: esi = 900000h, ecx = -200h
	shl	ecx, 12			; page to offset, (ex)-200000h
	add	esi, ecx		; (ex) esi = 700000h
	call	allocate_page_table

	clc
.exit:
	pop	esi
	pop	ecx
	ret

;------------------------------------------------------------------------------
; allocate page table
;------------------------------------------------------------------------------
; IN	esi = allocate page table for this linear address
;
; Ret	Cy = 0 success
;	Cy = 1 fail
;
proc4 allocate_page_table
	push	eax
	push	ecx
	push	edi
	push	esi
	push	es

	push	ALLMEM_sel
	pop	es

	mov	eax, [freeRAM_pages]
	test	eax, eax
	jz	.fail

	shr	esi, 20			;
	and	esi, 0ffch		;esi = page dir offset
	add	esi, [page_dir_ladr]	;esi = page table entry address
	test	b es:[esi], 1		;check P bit
	jnz	.exists

	dec	eax
	mov	[freeRAM_pages], eax

	mov	edi, [freeRAM_bm_ladr]	;edi - free RAM bitmap
	xor	eax, eax

.lp:
	inc	eax
	bt	es:[edi], eax
	jnc	.lp			; find free RAM page
	btr	es:[edi], eax		; store '0' bit
	shl	eax, 12			; eax = phisical address

	; page table zero clear
	push	eax
	cld
	mov	edi, eax
	xor	eax, eax
	mov	ecx, 1000h / 4
	rep	stosd
	pop	eax

	or	 al, 7			; page entry (P, R/W, U/S bit)
	mov	es:[esi], eax		; regist page table

.exists:
	clc
.exit:
	pop	es
	pop	esi
	pop	edi
	pop	ecx
	pop	eax
	ret

.fail:
	stc
	jmp	.exit

;##############################################################################
; subrotine
;##############################################################################
;------------------------------------------------------------------------------
; get maximum allcatable memory
;------------------------------------------------------------------------------
; IN	esi = base linear address
; Ret	eax = maximum pages
;
proc4 get_max_alloc_pages
	push	ebx
	push	ecx
	push	es

	push	DOSMEM_sel
	pop	es

	mov	eax, esi		;割りつけ先アドレス
	shr	eax, 20			;bit 31-20
	and	 al, 0fch		;bit 21,20 のクリア
	add	eax, es:[page_dir_ladr]	;割り付け先頭のページテーブルを確認

	xor	ebx, ebx
	test	eax, eax
	jz	.step			;存在しないときは jump

	mov	eax, esi		;割り付け先リニアアドレス
	shr	eax, 12
	and	eax, 03ffh		;使用済、ページエントリ数
	mov	ecx, 0400h ;=1024	;1テーブルの最大ペーシエントリ数
	sub	ecx, eax		;ecx = ページテーブ割当済、ページエントリ数

.step:
	mov	eax, [freeRAM_pages]	;残り物理ページ数ロード
	mov	ebx, eax		;
	sub	ebx, ecx		;ページテーブルの要らないエントリ数を引く
	add	ebx, 000003ffh		;繰り上げ処理をして 1024 で除算
	shr	ebx, 10			;ecx = ページテーブル用に必要なページ数
	sub	eax, ebx		;残りページ数 - ページテーブル用メモリ

	pop	es
	pop	ecx
	pop	ebx
	ret

;------------------------------------------------------------------------------
; get selector infomation address
;------------------------------------------------------------------------------
; IN	eax = selector
;	 ds = any
;
; Ret	ebx = selector address
;
proc4 get_selector_info_adr
	mov	ebx, cs:[LDT_adr]
	test	 al, 4
	jnz	.skip
	mov	ebx, cs:[GDT_adr]
.skip:
	push	eax
	and	 al, 0f8h	;clear bit0-2
	add	ebx, eax	;add
	pop	eax

	ret

;------------------------------------------------------------------------------
; get selector infomation address and base linear address
;------------------------------------------------------------------------------
; IN	eax = selector
;	 ds = any
;
; Ret	ebx = selector info address
;	esi = selector base address
;
proc4 get_selector_base_ladr
	call	get_selector_info_adr

	push	eax
	mov	esi, cs:[ebx+2]	;bit 0-23
	mov	eax, cs:[ebx+4]	;bit 24-31
	and	esi, 000ffffffh
	and	eax, 0ff000000h
	or	esi, eax	;composite
	pop	eax

	ret

;------------------------------------------------------------------------------
; get selector linear address of end
;------------------------------------------------------------------------------
; IN	eax = selector
; Ret	esi = end of linear address +1
;
proc4 get_selector_end_ladr
	push	ebx

	call	get_selector_base_ladr	;ebx = selector info adr
					;esi = selector base adr

	lsl	ebx, eax		;ebx = limit
	inc	ebx			;ebx = size
	add	esi, ebx		;eax = end of linear address +1

	pop	ebx
	ret

;------------------------------------------------------------------------------
; set selector limit with selector information address
;------------------------------------------------------------------------------
; IN	ebx = selector info address
;	ecx = new size [page]
;
proc4 set_selector_limit_iadr
	push	eax
	push	ecx

	test	ecx, ecx
	jnz	.non_zero

	; ecx is zero
	mov	[ebx], cx	;limit  bit0-15
	and	b [ebx+6], 70h	;clear G bit and limit bit16-19
	jmp	.end

.non_zero:
	dec	ecx		;size to limit

	mov	[ebx], cx	;limit  bit0-15
	shr	ecx, 16		;ecx = limit16-19
	mov	al, [ebx+6]
	and	al, 70h		;keep other bits
	and	cl, 0fh		;limit bit16-19
	or	al, cl		;mix
	or	al, 80h		;Force G bit (4K unit limit)
	mov	[ebx+6], al	;rewrite

.end:	pop	ecx
	pop	eax
	ret

;------------------------------------------------------------------------------
; search free selector in LDT
;------------------------------------------------------------------------------
; Ret	Cy = 0 Success
;		eax = free selctor
;	Cy = 1 Fail
;		eax = 0
;
proc4 search_free_LDTsel
	push	ebx
	push	ecx

	mov	eax,LDT_sel	;LDT のセレクタ値
	lsl	ecx,eax		;ecx = LDT サイズ
	mov	eax,[LDT_adr] 	;LDT のアドレス
	add	ecx,[LDT_adr] 	;LDT 終了アドレス
	add	eax,byte 4	;+4

.loop:	add	eax,byte 8	;アドレス更新
	cmp	eax,ecx		;サイズと比較
	ja	.no_desc	;サイズオーバ = ディスクリプタ不足
	test	b [eax+1],80h	;P ビット(存在ビット)
	jz	.found		;0 なら空きディスクリプタ
	jmp	short .loop

.found:
	sub	eax,[LDT_adr] 	;LDTアドレス先頭を引く
	pop	ecx		;eax = 空きセレクタ
	pop	ebx
	clc
	ret

.no_desc:
	xor	eax,eax		;eax =0
	pop	ecx
	pop	ebx
	stc
	ret

;------------------------------------------------------------------------------
; reload all selector
;------------------------------------------------------------------------------
proc4 reload_all_selector
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
; regist managed LDT selector
;------------------------------------------------------------------------------
; IN	ax = selector
;
proc4 regist_managed_LDTsel
	push	eax
	push	ecx

	mov	ecx, [managed_LDTsels]
	cmp	ecx, LDTsize/8
	jae	.exit				; ignore

	mov	[managed_LDTsel_list + ecx*2], ax
	inc	ecx
	mov	[managed_LDTsels], ecx

.exit:
	pop	ecx
	pop	eax
	ret

;------------------------------------------------------------------------------
; search managed LDT selector
;------------------------------------------------------------------------------
; IN	ax = selector
; Ret	Cy = 0 Found
;	Cy = 1 Not found
;
proc4 search_managed_LDTsel
	pusha
	call	do_search_managed_LDTsel
	popa
	ret

proc4 do_search_managed_LDTsel		; call from remove_managed_LDTsel
	mov	edx, [managed_LDTsels]
	mov	ebx, managed_LDTsel_list
	xor	ecx, ecx
.loop:
	cmp	[ebx + ecx*2], ax
	je	.found
	inc	ecx
	cmp	ecx, edx
	jb	.loop

.not_found:
	stc
	ret

.found:
	clc
	ret

;------------------------------------------------------------------------------
; remove managed  LDT selector
;------------------------------------------------------------------------------
; IN	ax = selector
;
; RET	cy = 0	removed
;	cy = 1	not found
;
proc4 remove_managed_LDTsel
	pusha

	call	do_search_managed_LDTsel
	jnc	.found

	;stc	;Cy is setted
	popa
	ret

.found:
	mov	ax, [ebx + edx*2 - 2]	; last
	mov	[ebx + ecx*2], ax	; copy
	dec	edx
	mov	[managed_LDTsels], edx

	clc
	popa
	ret

;------------------------------------------------------------------------------
; get free linear address to create a new selector.
;------------------------------------------------------------------------------
; Ret	esi = free linear address
;
proc4 get_free_linear_adr
	pusha

	mov	ecx, [managed_LDTsels]
	mov	ebx, managed_LDTsel_list
	xor	edi, edi		; edi = current highest linear address
	inc	ecx
.loop:
	dec	ecx
	jz	.exit

	movzx	eax, w [ebx]		; eax = selector
	add	ebx, 2

	; in eax = selector
	call	get_selector_end_ladr	; esi = selector end linear address
	cmp	esi, 4000_0000h		; 1GB / non RAM mapping?
	ja	.loop

	add	esi, LADR_HROOM_size	; head room for linear address
	cmp	edi, esi
	jae	.loop

	mov	edi, esi		; save current highest
	jmp	.loop

.exit:
	; edi = highest linear address
	mov	eax, [all_mem_pages]
	shl	eax, 12			; all RAM size

	cmp	edi, eax
	ja	.skip
	mov	edi, eax
.skip:
	; adjust to multiple of LADR_UNIT
	add	edi, LADR_UNIT -1
	and	edi, 0ffff_ffffh - (LADR_UNIT -1)

	mov	[esp +4], edi		; save to esi

	popa
	ret

;------------------------------------------------------------------------------
; rewrite managed LDT selector's limit
;------------------------------------------------------------------------------
; IN	ecx = new page size
;	esi = selector base address
;
proc4 rewrite_managed_LDTsels_limit
	pusha

	mov	ebp, esi		; selector base address
	mov	edx, managed_LDTsel_list
	xor	eax, eax
.loop:
	mov	ax, [edx]
	add	edx, 2
	test	eax, eax
	jz	.exit

	; eax = selector
	call	get_selector_base_ladr	; ebx=selector info, esi=base
	cmp	esi, ebp		; compare base address
	jne	.loop

	; found original or alias
	; ebx = selector info address
	; ecx = new page size
	call	set_selector_limit_iadr
	jmp	.loop

.exit:
	popa
	ret

;------------------------------------------------------------------------------
; get phisical address
;------------------------------------------------------------------------------
; IN	ebx = linear address
;	 ds = any
; Ret	 Cy = 0 Success
;		ecx = phisical address
;	 Cy = 1 Fail
;
proc4 get_phisical_address
	push	eax
	push	es

	push	ALLMEM_sel
	pop	es

	mov	ecx, ebx		;ecx = linear address
	shr	ecx, 20			;ecx = bit20-31
	and	 cl, 0fch
	add	ecx, cs:[page_dir_ladr]
	mov	ecx, es:[ecx]		;ecx = page table info
	test	 cl, 1			;P bit
	jz	.error

	mov	eax, ebx		;ecx = linear address
	shr	eax, 10			;ecx = bit 10-31
	and	eax, 0ffch		;clear bit 10-11 and 22-31
	and	ecx, 0fffff000h		;ecx = page table linear address
	mov	ecx, es:[ecx+eax]	;ecx = target page info
	test	 cl, 1			;P bit
	jz	.error			;if 0 jmp

	mov	eax, ebx		;ecx = linear address
	and	eax,      0fffh		;bit 11-0
	and	ecx, 0fffff000h		;ecx = phisical address bit 12-31
	or	ecx, eax

	clc
.exit:	pop	es
	pop	eax
	ret
.error:
	stc
	jmp	.exit

;//////////////////////////////////////////////////////////////////////////////
; DATA
;//////////////////////////////////////////////////////////////////////////////
segdata	data class=DATA align=4

global freeRAM_bm_ladr
global freeRAM_bm_size

;------------------------------------------------------------------------------
freeRAM_bm_size	dd	0		; bitmap size
freeRAM_pages	dd	0		; free phisical memory pages
freeRAM_bm_ladr	dd	0		; free phisical memory bitmap address
		dw	ALLMEM_sel

	align	4
managed_LDTsels		dd	0
managed_LDTsel_list:			; managed LDT selector list
  times (LDTsize/8)	dw	0

