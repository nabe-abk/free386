;******************************************************************************
;　Free386	PC-9801/9821 dependent code
;******************************************************************************
;
; Written by kattyo
;
; 2001/02/25 256色モード初期化追加
; 2001/02/25 256色モード初期化の手抜きを修正
;
seg16	text class=CODE align=4 use16
;==============================================================================
;★PC-98 簡易チェック
;==============================================================================
;Ret	Cy=0	PC-98 だと思ふ
;	Cy=1	PC-98 じゃない可能性が大きい
;
proc2 check_PC98_16
	xor	bx,bx
	mov	cx,6
	; Do not use multiples of 4.
	; "multiple of 4" is result 0 on timer#01/02
.loop:
	in	al,71h		;timer #00
	xor	bl,al		;xor
	in	al,73h		;timer #01
	xor	bh,al		;xor
	loop	.loop

 	test	bx,bx
 	jz	.not_pc98
 	clc
 	ret
.not_pc98:
	stc
	ret

	;*** 仕組み解説 ***
	;タイマはたえず変化してるので、何度読みだしても変化がなければ
	;そのI/O に タイマがある = PC-98 だと考える。

;==============================================================================
; init PC-98x1 in 16bit mode
;==============================================================================
proc2 init_PC98_16
	ret


BITS	32
;==============================================================================
;★PC-98x1 の初期設定
;==============================================================================
proc4 init_PC98_32
	;; 16 色 VRAM をリニアアドレス上に連続に張り付け
	mov	esi, VRAM_16padr	;張り付け先リニアアドレス = RGB GVRAM
	mov	edx, 0000A8000h		;張り付ける物理アドレス
	mov	ecx, 24			;ページ数
	call	set_physical_memory
	
	mov	esi, VRAM_16padr + 24*4096	;A
	mov	edx, 0000E0000h
	mov	ecx, 8
	call	set_physical_memory
	
	mov	eax, 0120h			;リニアアドレスのマップ
	mov	edi,[work_adr]			;ワーク
	mov	d [edi  ],VRAM_16padr		;リニアアドレス
	mov	d [edi+4],32			;32*4 = 128 KB
	mov	d [edi+8],0200h			;R/W
	call	make_selector_4k
	
	;; CG Window を e00a5000 に張り付け
	mov	esi, VRAM_CGW		;張り付け先リニアアドレス = RGB GVRAM
	mov	edx, 0000A4000h		;張り付ける物理アドレス
	mov	ecx, 1			;ページ数
	call	set_physical_memory
	
	mov	eax, 0138h			;リニアアドレスのマップ
	mov	edi,[work_adr]			;ワーク
	mov	d [edi  ],VRAM_CGW		;リニアアドレス
	mov	d [edi+4],1			;1*4 = 4 KB
	mov	d [edi+8],0200h			;R/W
	call	make_selector_4k
	
	
	;; TVRAM を e00a0000 に張り付け
	mov	esi, VRAM_TEXT		;張り付け先リニアアドレス = RGB GVRAM
	mov	edx, 0000A0000h		;張り付ける物理アドレス
	mov	ecx, 4			;ページ数
	call	set_physical_memory
	
	mov	eax, 0130h			;リニアアドレスのマップ
	mov	edi,[work_adr]			;ワーク
	mov	d [edi  ],VRAM_TEXT		;リニアアドレス
	mov	d [edi+4],4			;4*4 = 16 KB
	mov	d [edi+8],0200h			;R/W
	call	make_selector_4k
	
	
	;; 物理メモリのマッピング
	
	mov	ebx,offset PC98_memory_map	;物理アドレスのマップ
	call	map_memory			;
	jnc	.success

	mov	ah, 17		; not enough page table memory
	jmp	error_exit_32
.success:

	;; エイリアス作成

	mov	esi,offset PC98_selector_alias	;エイリアスの作成
	call	make_aliases			;

.c256mode_not_found:

	ret


;------------------------------------------------------------------------------
;★PC-98x1 の終了処理
;------------------------------------------------------------------------------
proc4 exit_PC98_32
	mov	bl,[reset_CRTC]		;reset / 1 = 初期化, 2 = CRTCのみ
	test	bl,bl			;0 ?   / 3 = 自動認識
	jz	.no_reset		;ならば初期化せず

	;*** CRTC の初期化 ***
	cmp	bl,3			;自動認識 ?
	jne	.res_c			; でなければ jmp

	;*** 256モード描画を確認 *******
	mov	edi,[GDT_adr]		;GDT アドレスロード
	mov	esi,[LDT_adr]		;LDT アドレスロード
	mov	 cl,[edi + 128h   +5]	;GDT:VRAM (256)
	or	 cl,[esi + 10ch-4 +5]	;LDT:VRAM (256)
	test	 cl,01			;上のどれかに アクセスあり ?
	jz	.no_reset_CRTC		;なければ jmp

.res_c:	call	PC98_DOS_CRTC_init	;CRTC 初期化
.no_reset_CRTC:

	;*** VRAM の初期化 ***
	;mov	bl,[reset_CRTC]
	cmp	bl,2			;VRAM は初期化しない ?
	je	.no_reset_VRAM		;等しければ jmp

	cmp	bl,1			;必ず初期化 ?
	je	.res_v256		;等しければ jmp
	test	cl,01			;256色VRAMに アクセスあり ?
	jz	.chk_16VRAM		;なければ jmp

.res_v256:
	push	esi
	push	edi
	mov	eax,128h		;VRAM セレクタ
	mov	  es,ax			;Load
	xor	edi,edi			;edi = 0
	mov	ecx,512*1024 / 4	;512 KB
	xor	eax,eax			;塗りつぶす値
	rep	stosd			;0 クリア
	pop	edi
	pop	esi

.chk_16VRAM:
	cmp	bl,1			;必ず初期化 ?
	je	.res_v16		;等しければ jmp

	mov	 al,[edi + 120h   +5]	;GDT:VRAM (16)
	or	 al,[esi + 104h-4 +5]	;LDT:VRAM (16)
	test	 al,01			;16色VRAMに アクセスあり ?
	jz	.no_reset_VRAM		;0 なら VRAM 未使用 (jmp)

.res_v16:
	mov	eax,120h		;VRAM セレクタ
	mov	  es,ax			;Load
	xor	edi,edi			;edi = 0
	mov	ecx,128*1024 / 4	;128 KB
	xor	eax,eax			;塗りつぶす値
	rep	stosd			;0 クリア
.no_reset_VRAM:
.no_reset:
	ret


;------------------------------------------------------------------------------
;★CRTC 初期化
;------------------------------------------------------------------------------
	align	4
PC98_DOS_CRTC_init:
	;------------------------------------------
	; 256 色モードの場合は 16 色モードに戻す
	;------------------------------------------
	mov	al, 007h	;モード変更可
	out	06Ah, al
	mov	al, 020h	;標準グラフィックスモード
	out	06Ah, al
	mov	al, 006h	;モード変更不可
	out	06Ah, al

	;/// 画面表示停止 //////////////
%if STOP_GVRAM
	mov	al, 00Ch
	out	0A2h, al	;画面表示停止
%endif
	ret


BITS	16
;==============================================================================
; exit process for PC/AT in 16bit
;==============================================================================
proc2 exit_PC98_16
	ret



;******************************************************************************
; DATA
;******************************************************************************
segdata	data class=DATA align=4

	align	4
PC98_memory_map:
		;sel, base     ,  pages,  type
	dd	128h, 0fff00000h, 512/4,  0200h	;R/W : VRAM (256c)
;	dd	160h, 020000000h, 4096/4, 0200h	;R/W : VRAM (TGUI vram)
;	dd	168h, 020400000h, 64/4,   0200h	;R/W : VRAM (TGUI mmio)
;	dd	170h, 020800000h, 4096/4, 0200h	;R/W : VRAM (TGUI vram)
	dd	0	;end of data

	align	4
PC98_selector_alias:
		;ORG, alias, type
	dd	120h,  104h,  0200h	;VRAM (16)
	dd	128h,  10ch,  0200h	;VRAM (256)
	dd	130h,  114h,  0200h	;TVRAM
	dd	0	;end of data

