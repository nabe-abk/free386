;******************************************************************************
;　Free386	PC-9801/9821 dependent code
;******************************************************************************
;
; Written by kattyo
;
; 2001/02/25 256色モード初期化追加
; 2001/02/25 256色モード初期化の手抜きを修正
;
segment	text class=CODE align=4 use16
;==============================================================================
;★PC-98 簡易チェック
;==============================================================================
;Ret	Cy=0	PC-98 だと思ふ
;	Cy=1	PC-98 じゃない可能性が大きい
;
proc16 check_PC98_16
	xor	ah,ah		;AH = 0
%rep	2		;偶数回繰り返し（4の倍数 を指定すると98で謎の誤判別）
	in	al,73h		;タイマ カウンタ#01
 	xor	ah,al		;xor
	in	al,75h		;タイマ カウンタ#02
 	xor	ah,al		;xor
%endrep

 	test	ah,ah		;値確認
	jz	.not_pc98	;0 なら PC-98 ではない
	clc	;成功
	ret

.not_pc98:
	stc	;失敗
	ret

	;*** 仕組み解説 ***
	;タイマはたえず変化してるので、何度読みだしても変化がなければ
	;そのI/O に タイマがある = PC-98 だと考える。

;==============================================================================
; init PC-98x1 in 16bit mode
;==============================================================================
proc16 init_PC98_16
	ret


BITS	32
;==============================================================================
;★PC-98x1 の初期設定
;==============================================================================
proc32 init_PC98_32
	mov	eax,[free_liner_adr]	;空きリニアアドレス
	mov	ebx,0x1000000		;16MB
	cmp	eax,ebx
	ja	.liner_adr_ok		;16MB未満なら
	mov	[free_liner_adr],ebx	;16MBに引き上げ
.liner_adr_ok:

	;; 16 色 VRAM をリニアアドレス上に連続に張り付け
	mov	esi, VRAM_16padr	;張り付け先リニアアドレス = RGB GVRAM
	mov	edx, 0000A8000h		;張り付ける物理アドレス
	mov	ecx, 24			;ページ数
	call	set_physical_mem
	
	mov	esi, VRAM_16padr + 24*4096	;A
	mov	edx, 0000E0000h
	mov	ecx, 8
	call	set_physical_mem
	
	mov	eax, 0120h			;リニアアドレスのマップ
	mov	edi,[work_adr]			;ワーク
	mov	d [edi  ],VRAM_16padr		;リニアアドレス
	mov	d [edi+4],32-1			;32*4 = 128 KB
	mov	d [edi+8],0200h			;R/W
	call	make_selector_4k
	
	;; CG Window を e00a5000 に張り付け
	mov	esi, VRAM_CGW		;張り付け先リニアアドレス = RGB GVRAM
	mov	edx, 0000A4000h		;張り付ける物理アドレス
	mov	ecx, 1			;ページ数
	call	set_physical_mem
	
	mov	eax, 0138h			;リニアアドレスのマップ
	mov	edi,[work_adr]			;ワーク
	mov	d [edi  ],VRAM_CGW		;リニアアドレス
	mov	d [edi+4],1-0			;1*4 = 4 KB
	mov	d [edi+8],0200h			;R/W
	call	make_selector_4k
	
	
	;; TVRAM を e00a0000 に張り付け
	mov	esi, VRAM_TEXT		;張り付け先リニアアドレス = RGB GVRAM
	mov	edx, 0000A0000h		;張り付ける物理アドレス
	mov	ecx, 4			;ページ数
	call	set_physical_mem
	
	mov	eax, 0130h			;リニアアドレスのマップ
	mov	edi,[work_adr]			;ワーク
	mov	d [edi  ],VRAM_TEXT		;リニアアドレス
	mov	d [edi+4],4-1			;4*4 = 16 KB
	mov	d [edi+8],0200h			;R/W
	call	make_selector_4k
	
	
	;; 物理メモリのマッピング
	
	mov	ebx,offset PC98_memory_map	;物理アドレスのマップ
	call	map_memory			;

	;; エイリアス作成

	mov	esi,offset PC98_selector_alias	;エイリアスの作成
	call	make_aliases			;

.c256mode_not_found:

	ret


;------------------------------------------------------------------------------
;★PC-98x1 の終了処理
;------------------------------------------------------------------------------
proc32 exit_PC98_32
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
%if (STOP_GVRAM)
	mov	al, 00Ch
	out	0A2h, al	;画面表示停止
%endif
	ret


BITS	16
;==============================================================================
; exit process for PC/AT in 16bit
;==============================================================================
proc16 exit_PC98_16
	ret



;******************************************************************************
; DATA
;******************************************************************************
segment	data class=DATA align=4

	align	4
PC98_memory_map:
		;sel, base     , pages -1, type
	dd	128h, 0fff00000h, 512/4 -1, 0200h	;R/W : VRAM (256c)
;	dd	160h, 020000000h, 4096/4 -1, 0200h	;R/W : VRAM (TGUI vram)
;	dd	168h, 020400000h, 64/4 -1, 0200h	;R/W : VRAM (TGUI mmio)
;	dd	170h, 020800000h, 4096/4 -1, 0200h	;R/W : VRAM (TGUI vram)
	dd	0	;end of data

	align	4
PC98_selector_alias:
		;ORG, alias, type
	dd	120h,  104h,  0200h	;VRAM (16)
	dd	128h,  10ch,  0200h	;VRAM (256)
	dd	130h,  114h,  0200h	;TVRAM
	dd	0	;end of data

