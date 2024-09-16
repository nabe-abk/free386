;******************************************************************************
;　Free386	PC/AT dependent code
;******************************************************************************
;
seg16	text class=CODE align=4 use16
;==============================================================================
; check maachine type is PC/AT
;==============================================================================
;Ret	Cy=0	true
;	Cy=1	false
;
proc2 check_AT_16
	xor	bx,bx		;AH = 0
	mov	cx,16
.loop:
	in	al,40h		;timer #00
	xor	bl,al		;xor
	in	al,41h		;timer #01
	xor	bh,al		;xor
	loop	.loop

 	test	bx,bx
 	jz	.not_AT
	clc
	ret

.not_AT:
	stc
	ret

;==============================================================================
; init PC/AT in 16bit mode
;==============================================================================
proc2 init_AT_16
	ret


BITS	32
;==============================================================================
;★PC/AT互換機の初期設定
;==============================================================================
proc4 init_AT_32
	mov	ebx,offset AT_memory_map	;メモリのマップ
	call	map_memory			;
	jnc	.success
	mov	ah, 17		; not enough page table memory
	jmp	error_exit_32

.success:
	mov	esi,offset AT_selector_alias	;エイリアスの作成
	call	make_aliases			;

	;--------------------------------------------------
	; check VESA3.0
	;--------------------------------------------------
%if VESA_DISABLE
	jmp	.no_VESA
%endif
	mov	ax,4f00h	;install VESA?
	mov	di,[work_adr]	;バッファアドレス (ボード名/Ver など多数が返る)
	V86_INT	10h		;VGA/VESA BIOS call
	cmp	ax,004fh	;サポートされてる？
	jne	.no_VESA	;違えば VESA なし(jmp)

	;/// VESA3.0 Protect Mode Bios の検索 //////
	push	b (DOSMEM_sel)
	pop	es

	mov	eax,'PMID'	;In other ASM 'DIMP'
	mov	edi,0c0000h	;VESA-BIOS
	mov	edx,0c8000h	;検索終了アドレス

	align	4
	;*** 低速な検索ルーチン(改良求む) ***
.loop:	cmp	[es:edi],eax	;プロテクトモードインフォメーションブロック？
	je	.check_PMIB	;
	inc	edi
	cmp	edi,edx		;終了アドレス？
	jne	.loop
	jmp	.no_VESA	;発見できず

	align	4
.check_PMIB:			;チェックサムの確認
	mov	ecx,13h
	mov	al,[es:edi]	;先頭

	align	4
.check_loop:
	add	al,[es:edi+ecx]	;加算
	loop	.check_loop
	test	al,al		;al=0?
	jnz	.loop		;check sum error なら続き検索

	;/// VESA3.0 Protect Mode Interface発見 ///
	xor	esi,esi
	call	AT_VESA30_alloc	;VESA3.0 PMode-BIOS の配置

	align	4
.no_VESA:
	ret


;------------------------------------------------------------------------------
;★VESA 3.0 Protect Mode Interface のセットアップ
;------------------------------------------------------------------------------
	align	4
AT_VESA30_alloc.exit:
	ret

	align	4
AT_VESA30_alloc:
	and	edi,7fffh		;上位ビットを無視
	mov	[VESA_PMIB],edi		;プロテクトモード構造体の offset

	mov	ecx,64/4 +1 +VESA_buf_size	;64KB + 4KB + buf のメモリ

	call	get_free_linear_adr	;esi = linear address
	call	allocate_RAM		;ecx = pages
	jc	.exit			;エラーなら exit

	mov	edi,[work_adr]		;ワークアドレスロード

	;/// VESA 呼び出し時のワーク ///
	mov	d [edi  ],esi		;ベースアドレス
	mov	d [edi+4],VESA_buf_size	;size
	mov	d [edi+8],0200h		;R/X / 特権レベル=0
	mov	eax,VESA_buf_sel	;VESA buffer segment
	call	make_selector_4k		;メモリセレクタ作成 edi=構造体 eax=sel

	;/// VESA Code Selector ////////
	add	esi,(VESA_buf_size+1)*1000h	;4KB 余分にずらす
	mov	d [edi  ],esi		;ベースアドレス
	mov	d [edi+4],10000h	;size 64KB (32KB ではダメ)
	mov	d [edi+8], 1a00h	;R/X 286 / 特権レベル=0
	mov	eax,VESA_cs		;VESA code segment
	call	make_selector		;メモリセレクタ作成 edi=構造体 eax=sel

	;/// VESA Data Selector ////////
	mov	d [edi+8],1200h		;R/W 286 / 特権レベル=0
	mov	eax,VESA_ds		;VESA data segment(cs alias)
	call	make_selector		;メモリセレクタ作成 edi=構造体 eax=sel

	;/// VESA 環境 Selector ////////
	sub	esi,1000h		;4KB戻す
	mov	edi,[work_adr]		;ワークアドレスロード
	mov	d [edi  ],esi		;ベースアドレス
	mov	d [edi+4],1		;size (4KB)
	mov	d [edi+8],0200h		;R/W / 特権レベル=0
	mov	eax,VESA_ds2		;VESA data segment
	call	make_selector_4k		;メモリセレクタ作成 edi=構造体 eax=sel

	;/// VESA 環境データクリア /////
	mov	eax,VESA_ds2		;環境データセレクタ
	mov	 es,ax			;セレクタ設定
	xor	edi,edi			;edi = 0
	mov	ecx,600h / 4		;600h /4
	xor	eax,eax			;0 クリア
	rep	stosd			;塗り潰し

	;/// VESA-BIOS のコピー ////////
	mov	eax,VESA_ds		;VESA BIOS の書き込み先
	mov	ebx,DOSMEM_sel		;VESA BIOS 転送元セレクタ
	mov	 es,ax			;セレクタ設定
	mov	 ds,bx			;
	xor	edi,edi			;edi = 0
	mov	esi,0c0000h		;VESA BIOS
	mov	ecx, 10000h / 4		;64KB /4
	rep	movsd

	mov	ebp,F386_ds		;
	mov	ds ,ebp			;ds 復元
	mov	edi,[VESA_PMIB]		;PM BIOS 構造体

	;/// PM-BIOS 構造体 への設定 ///
	mov	w [es:edi+08h],VESA_ds2	;環境セレクタ
	mov	w [es:edi+0ah],VESA_A0	;a0000h - bffffh
	mov	w [es:edi+0ch],VESA_B0	;b0000h - bffffh
	mov	w [es:edi+0eh],VESA_B8	;b8000h - bffffh
	mov	w [es:edi+10h],VESA_ds	;VESA cs alias
	mov	b [es:edi+12h],1	;in Protect Mode

	;*** far return op-code の張り付け ****
	mov	w [es:0fffeh],0cb66h	;32bit far return

	;*** VESA-BIOS の初期化 ********
	movzx	ecx,w [es:edi+6]	;初期化ルーチン位置
	push	ds			;ds 保存
	push	cs
	push	offset .VESA_ret0	;戻りラベル
	push	0fffeh		;far return op-code のあるアドレス
	push	VESA_cs
	push	ecx			;初期化ルーチン
	retf				;ルーチンコール
	;注意！
	;　VESA3.0 の Protect Mode Bios は、Linux などのセグメントを
	;使用しない環境を想定してか、(o32) near return するようになっている(;_;

.VESA_ret0:
	mov	es,[esp]		;es = F386_ds
	pop	ds			;ds 復元
	PRINT32	VESA30_init		;初期化成功のメッセージ

	;----------------------------------------------------------------------
	;VESA bios call の準備
	;----------------------------------------------------------------------
	mov	ebx,offset VESA_call_point	;call 命令位置
	mov	edx,offset VESA_call_point2	;
	mov	eax,[VESA_PMIB]			;プロテクトモード構造体の位置
	add	eax,byte 4			;entry point の位置
	mov	[ebx-2],ax			;call 文の参照メモリの書き換え
	mov	[edx-2],ax			;

	push	es
	mov	eax,VESA_ds			;VESAデータセグメント(cs alias)
	mov	 es,ax				;es 設定
	mov	edi,VESA_call_adr		;call プログラム設定位置
	mov	esi,offset VESA_call		;コピー元

	mov	ecx,(VESA_call_end-VESA_call)/4	;ルーチンサイズ /4
	rep	movsd				;call-code の転送

	;----------------------------------------------------------------------
	;VRAM の張り付け
	;----------------------------------------------------------------------
	push	cs
	push	offset .VESA_ret1	;戻りラベル
	push	VESA_cs		;

	mov	eax,offset VESA_call2 + VESA_call_adr
	sub	eax,offset VESA_call	;差を算出
	push	eax			;call-code アドレス

	mov	ebx,VRAM_sel		;VRAM_sel
	mov	  es,bx			;es に VRAMセレクタ設定
	mov	edx,VRAM_padr		;設定する物理アドレス
	mov	 cx,dx			;cx = bit  0-15
	shr	edx,16			;dx = bit 31-16

	mov	ax,4f07h		;物理メモリの設定
	xor	ebx,ebx			;bl=bh=0
	retf				;ルーチンコール

	align	4
.VESA_ret1:
	pop	es
	ret

VESA_entry:
	dd	VESA_call_adr
	dw	VESA_cs

	;------------------------------------------------
	;VESA bios call のためのルーチン (Copy して使う)
	;------------------------------------------------
	align	4
BITS	16
VESA_call:
	push	es
	push	w (VESA_buf_sel)	;es = バッファセレクタ
	pop	es			;

	xor	di,di			;es:di = buffer
	push	di	;=push 0	;32bit return を発行してるので >VESA
	call	word [cs:0000h]		;VESA-BIOS call
VESA_call_point:
	pop	es
	db	66h			;size pureffix (次の命令をuse32で解釈)
	retf				;32bit retf

	align	4
	;/// es指定 call ///////////////
VESA_call2:
	push	w 0
	call	word [cs:0000h]
VESA_call_point2:
	db	66h
	retf

	align	4			;消去不可！！
VESA_call_end:
BITS	32


BITS	32
;==============================================================================
; exit process for PC/AT in 32bit
;==============================================================================
proc4 exit_AT_32
	ret


BITS	16
;==============================================================================
; exit process for PC/AT in 16bit
;==============================================================================
proc2 exit_AT_16
	ret


;******************************************************************************
; DATA
;******************************************************************************
segdata	data class=DATA align=4

	align	4
AT_memory_map:
		; sel  ,  base     ,     pages, type/level
	dd	100h   , 0ffff0000h,      64/4, 0a00h ;R/X boot-ROM
	dd	VESA_A0,    0a0000h,      64/4, 0200h ;R/W for VESA 3.0
	dd	VESA_B0,    0b0000h,      64/4, 0200h ;R/W for VESA 3.0
	dd	VESA_B8,    0b8000h,      32/4, 0200h ;R/W for VESA 3.0
	dd	VRAM_sel, VRAM_padr,VRAM_pages, 0200h ;R/W VRAM
	dd	0	;end of data

	align	4
AT_selector_alias:
		;ORG, alias, type/level
	dd	100h,  108h,  0000h	;boot-ROM
	dd	120h,  128h,  0200h	;VRAM alias
	dd	120h,  104h,  0200h	;VRAM alias
	dd	128h,  10ch,  0200h	;VRAM alias
	dd	0			;end of data


VESA_PMIB	dd	0		;VESA Protect-Mode-Info-Block
VESA30_init	db	'VESA3.0 Protect Mode BIOS initalized!!',13,10,'$'

