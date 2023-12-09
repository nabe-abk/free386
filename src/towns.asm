;******************************************************************************
;　Free386	FM TOWNS dependent code
;******************************************************************************
;
BITS	16
;==============================================================================
;★TOWNS 簡易チェック
;==============================================================================
;Ret	Cy=0	TOWNS かもしれない
;	Cy=1	TOWNS でないかも?
;
proc check_TOWNS_16
	in	al,30h		;CPU 識別レジスタ
	test	al,al		;=and／値 check
	jz	.not_fm		;0 なら FM シリーズでない
	inc	al		;+1 する
	jz	.not_fm		;0ffh でも FM シリーズでない

	;FM だけど TOWNS??
	mov	dx,020eh	;ドライブスイッチレジスタ(TOWNS のみ)
	in	al,dx		;内蔵FD と 外付FD を交換できる
	and	al,0feh		;bit 7～1 を and する
	jnz	.not_TOWNS	;all 0 でなければ TOWNS ではない

	clc	;成功
	ret

.not_fm:
.not_TOWNS:
	stc	;失敗
	ret

;==============================================================================
;★CoCo情報の保存
;==============================================================================
; ※CALLバッファに保存する
;
proc init_TOWNS_16
	;
	; 386SX判定
	;
	in	al, 30h
	cmp	al, 03h			; 386SX
	jne	.skip_386sx
	mov	b [cpu_is_386sx], 1
.skip_386sx:
	;
	; VCPI情報から総メモリ容量の修正
	;
	in	al, 31h
	cmp	ax, 01h			; 初代TOWNS
	je	.skip

	xor	eax, eax
	mov	dx, 5e8h		; メモリ容量レジスタ（初代にはない）
	in	al, dx			; al MB
	and	al, 07fh
	shl	eax, 8			; MB to pages
	mov	[all_mem_pages], eax
.skip:
	call	init_CoCo
	ret

;==============================================================================
;★CoCo情報の保存
;==============================================================================
; ※CALLバッファに保存する
proc init_CoCo
	mov	ax, 0c000h	; CoCo存在確認
	int	8eh
	test	ah, ah
	jnz	.fail

	cmp	bh, 32h
	jb	.fail
	cmp	cx, 436fh	; 'Co'
	jne	.fail
	cmp	dx, 436fh	; 'Co'
	jne	.fail
	cmp	si, 204bh	; ' K'
	jne	.fail
	cmp	di, 656eh	; 'en'
	jne	.fail

	; int 8eh ax=c10ch
	;	機能不明だが、何かを登録している。
	;	この処理をしないと TMENU.EXG が起動しない。
	;	仕方ないので、RUN386の値をコピーし定数で処理。
	mov	ax, 0c10ch
	mov	cx, 2
	mov	si, 0
	mov	dx, 0b107h
	int	8eh

	;
	; [Regist] real mode to 32bit mode far call routine
	;
	mov	dx, cs
	mov	bx, offset callf32_from_V86
	mov	ax, 0c207h
	int	8eh

	mov	b [load_nsdd], 1
.fail:
	ret


BITS	32
;==============================================================================
;★T-OS のメモリ周り設定
;==============================================================================
proc init_TOWNS_32
	mov	ebx,offset T_OS_memory_map

	mov	al, [cpu_is_386sx]
	test	al, al
	jz	.skip
	mov	ebx,offset T_OS_memory_map_386sx
.skip:
	call	map_memory			;

	mov	esi,offset T_OS_selector_alias	;エイリアスの作成
	call	make_aliases			;

	;------------------------------------------
	;T-BIOS の張りつけ / thanks to Mamiya (san)
	;------------------------------------------
	;port(0x3b90) TBIOS物理アドレス
	;port(0x3b98) TBIOSサイズ
	;port(0x3ad0) TBIOSワーク物理アドレス(512byte)

	mov	dx,3b90h		;T-BIOS ベースアドレス読み出し
	call	TOWNS_CMOS_READ		;ebx <- READ
	mov	esi,ebx			;esi = address

	mov	dx,3b98h		;T-BIOS サイズ読み出し
	call	TOWNS_CMOS_READ		;ebx <- READ
	dec	ebx			;ebx = limit

	;/// セレクタ作成 //////
	mov	edi,[work_adr]		;ワークメモリ
	mov	d [edi  ],esi		;base
	mov	d [edi+4],ebx		;limit

	mov	d [edi+8],0a00h		;R/X / 特権レベル=0
	mov	eax,TBIOS_cs		;全メモリアクセスセレクタ
	call	make_selector		;メモリセレクタ作成 edi=構造体 eax=sel

	mov	d [edi+8],0200h		;R/W / 特権レベル=0
	mov	eax,TBIOS_ds		;全メモリアクセスセレクタ
	call	make_selector		;メモリセレクタ作成 edi=構造体 eax=sel

	;------------------------------------------
	;VRAMの書き換えチェック用の値
	;------------------------------------------
	mov	edi,[GDT_adr]		;GDT アドレスロード
	mov	 al,[edi + F386_ds +5]	;タイプフィールドロード
	test	 al,01
	jnz	.not_emulator

	push	es
	mov	b [is_emulator], 1
	mov	ebx, 128h
	mov	es, bx
	mov	d [es:07fffch], 011011011h
	pop	es
.not_emulator:

	;------------------------------------------
	;NSDD初期化
	;------------------------------------------
	cmp	b [load_nsdd], 0
	jz	short .no_nsdd

	call	wakeup_nsdd
.no_nsdd:
	ret

;------------------------------------------------------------------------------
; NSD driver setup and wakeup
;------------------------------------------------------------------------------
proc wakeup_nsdd
	mov	eax, LDT_sel
	mov	 fs, eax

	xor	ebx, ebx
	xor	edx, edx
	xor	ebp, ebp	; ebp = 0
.loop:
	mov	 ax, 0c103h	; get NSD driver info
	mov	ecx, ebp	; cx = driver number
	mov	edi, [work_adr]
	int	8eh
	test	ah, ah
	jnz	.exit

	; cx = Num of drivers(n)
	; bx = cs (LDT)
	; dx = ds (LDT)
	; [ds:edi]
	;	 LDT Format, limit byte
	;	 FF 7F 00 80  21 9A 40 00 - FF 7F 00 80  21 92 40 00
	;	 4C 00 00 00  00 00 00 00 - 44 00 00 00  00 00 00 00
	;
	mov	esi, ebx
	and	esi, 00000fff8h	; selector to offset
	mov	eax, [edi]
	mov	[fs:esi  ], eax
	mov	eax, [edi+04h]
	mov	[fs:esi+4], eax

	mov	esi, edx
	and	esi, 00000fff8h	; selector to offset
	mov	eax, [edi+08h]
	mov	[fs:esi  ], eax
	mov	eax, [edi+0ch]
	mov	[fs:esi+4], eax

	mov	 al, NSDD_wakeup
	call	send_command_to_nsdd

	inc	ebp
	jmp	.loop

.exit:
	ret


proc send_command_to_nsdd
	;  al = command
	; ebx = code selector
	push	gs
	push	ebx
	push	edi

	mov	edi, [work_adr]
	mov	gs, ebx
	mov	[edi+4], ebx

	movzx	ebx, w [gs:NSDD_stra_adr]	; +06h  strategy  entry
	mov	[edi], ebx

	mov	ebx, edi
	add	ebx, 10h
	mov	w [ebx], 000dh
	mov	[ebx+2], al			; save command code

	call	far [edi]			; call strategy


	movzx	eax, w [gs:NSDD_intr_adr]	; +08h  interrupt entry
	mov	[edi], eax

	call	far [edi]			; call interrupt

	pop	edi
	pop	ebx
	pop	gs
	ret

;------------------------------------------------------------------------------
;★TOWNS の C-MOS dword 読み出し
;------------------------------------------------------------------------------
	align	4
TOWNS_CMOS_READ:
	add	edx,byte 6	;+3 byte の位置
	in	al,dx		;(C-MOS は偶数番地に張りつけてある)
	mov	bh,al
	sub	edx,byte 2

	in	al,dx		;+2 byte の位置
	mov	bl,al
	sub	edx,byte 2

	shl	ebx,16

	in	al,dx		;+1 byte の位置
	mov	bh,al
	sub	edx,byte 2

	in	al,dx		;+0 byte / 指定番地
	mov	bl,al
	ret


;==============================================================================
;★TOWNS の終了処理
;==============================================================================
proc exit_TOWNS_32
	;------------------------------------------
	;NSDD 終了処理
	;------------------------------------------
	cmp	b [load_nsdd], 0
	jz	short .no_nsdd

	mov	b [load_nsdd], 0	;再入防止
	call	sleep_nsdd		;NSDドライバを停止させる
.no_nsdd:

	;--------------------------------------------------------
	;画面の初期化
	;--------------------------------------------------------
	mov	al,[reset_CRTC]		;reset / 1 = 初期化, 2 = CRTCのみ
	test	al,al			;0 ?   / 3 = 自動認識
	jz	near .no_reset		;ならば初期化せず

	;*** CRTC の初期化 ***
	cmp	al,3			;自動認識 ?
	jne	.res_c			; でなければ jmp

	;*** VRAMが書き換わっている？ ***
	cmp	b [is_emulator], 0
	je	.not_emulator

	push	es
	mov	ebx, 128h
	mov	es, bx
	mov	eax, [es:07fffch]
	pop	es

	mov	 bl, 1			;reset VRAM flag
	cmp	eax, 011011011h
	jne	.res_c

.not_emulator:
	;*** check VRAM access bit ***
	mov	edi,[GDT_adr]		;GDT アドレスロード
	mov	esi,[LDT_adr]		;LDT アドレスロード
	mov	 al,[edi + TBIOS_cs +5]	;タイプフィールドロード
	mov	 bl,[esi + 120h   +5]	;GDT:VRAM (16/32k)
	or	 bl,[esi + 128h   +5]	;GDT:VRAM (256)
	or	 bl,[esi + 104h-4 +5]	;LDT:VRAM (16/32k)
	or	 bl,[esi + 10ch-4 +5]	;LDT:VRAM (256)
	or	al,bl
	test	al,01			;アクセスあり ?
	jz	.no_reset_CRTC		;0 なら T-BIOS 未使用 (jmp)
.res_c:
	push	ebx
	call	TOWNS_DOS_CRTC_init	;CRTC 初期化
	pop	ebx

.no_reset_CRTC:

	;*** VRAM の初期化 ***
	mov	al,[reset_CRTC]
	cmp	al,2			;VRAM は初期化しない ?
	je	.no_reset_VRAM		;等しければ jmp
	cmp	al,1			;必ず初期化 ?
	je	.res_v			;等しければ jmp

	test	bl,01			;VRAMに アクセスあり ?
	jz	.no_reset_VRAM		;0 なら VRAM 未使用 (jmp)

.res_v:	push	es
	mov	eax,120h		;VRAM セレクタ
	mov	 es,eax			;Load
	xor	edi,edi			;edi = 0
	mov	ecx,512*1024 / 4	;512 KB
	xor	eax,eax			;塗りつぶす値
	rep	stosd			;0 クリア
	pop	es
.no_reset_VRAM:
.no_reset:
	ret

;------------------------------------------------------------------------------
;★NSDドライバを sleep させる
;------------------------------------------------------------------------------
proc sleep_nsdd
	mov	ax, 0c003h
	int	8eh
	test	ah, ah
	jnz	.exit

	mov	ebp, ecx	; ebp=常駐ドライバの数
	xor	ebx, ebx

.loop:
	test	ebp, ebp
	jz	.exit
	dec	ebp

	mov	 ax, 0c103h	; 常駐ドライバの情報取得
	mov	ecx, ebp	; cx = 常駐ドライバ番号
	mov	edi, [work_adr]
	int	8eh
	test	ah, ah
	jnz	.loop

	; cx = Num of drivers(n)
	; bx = cs (LDT)
	; dx = ds (LDT)

	mov	al, NSDD_sleep
	call 	send_command_to_nsdd
		;  al = command
		; ebx = code selector

	jmp	short .loop
.exit:
	ret


;------------------------------------------------------------------------------
;★CRTC 初期化
;------------------------------------------------------------------------------
;	Special thanks to りう氏 (CRTC操作データ)
;
	align	4
TOWNS_DOS_CRTC_init:
	;///////////////////////////////
	;/// 画面出力off ///////////////
	mov	dx,0FDA0h	;出力制御レジスタ
	xor	al,al		;al
	out	dx,al		;画面出力off

	;///////////////////////////////
	;/// CRTC レジスタの操作 ///////
	mov	ebx,offset TOWNS_CRTC_data
	xor	ecx,ecx
	mov	dh,4h		;CRTC レジスタの上位ビット

	align	4
.loop1:
	mov	dl,40h		;CRTC アドレスレジスタ (dx=440h)
	mov	al,cl		;アドレス番号
	out	dx,al		;アドレス出力
	inc	cl		;アドレス更新

	mov	dl,42h		;CRTC データレジスタ (dx=442h)
	mov	ax,[ebx]	;テーブルから出力値読み出し
	out	dx,ax		;word 出力
	add	ebx,byte 2	;アドレス更新

	cmp	cl,20h		;終了値 ?
	jne	.loop1

	;///////////////////////////////
	;/// CRTC 出力レジスタの操作 ///
	mov	dl,48h		;CRTC 出力レジスタ・コマンド (dx=448h)
	mov	al,00h		;アドレス = 0
	out	dx,al
	mov	dl,4ah		;CRTC 出力レジスタ・データ (dx=44ah)
	mov	al,15h		;コマンド = 15h
	out	dx,al

	mov	dl,48h		;CRTC 出力レジスタ・コマンド (dx=448h)
	out	dx,al		;アドレス = 1
	mov	dl,4ah		;CRTC 出力レジスタ・データ (dx=44ah)
	mov	al,09h		;コマンド = 09h
	out	dx,al		;

	;///////////////////////////////
	;/// パレットの設定 ////////////
	mov	ah,08h				;Layer 0
	mov	ebx, offset TOWNS_PAL_layer0	;パレットデータ
	call	.setPalette16

	mov	ah,28h				;Layer 1
	mov	ebx, offset TOWNS_PAL_layer1	;パレットデータ
	call	.setPalette16

	;///////////////////////////////
	;/// FM-R互換出力の設定 ////////
	mov	dx,0ff81h	;FM-R display I/O
	mov	al,0fh
	out	dx,al

	mov	dl,82h		;dx = ff82h
	mov	al,67h
	out	dx,al

	mov	dx,458h		;
	xor	al,al		;al = 0
	out	dx,al
	mov	dl,5ah
	mov	eax,0ffffffffh	
	out	dx,eax

	mov	dx,458h		;
	mov	al,1		;al = 1
	out	dx,al
	mov	dl,5ah
	mov	eax,0ffffffffh	
	out	dx,eax

	;///////////////////////////////
	;/// 画面出力on ////////////////
	mov	dx,0FDA0h	;出力制御レジスタ
	mov	al,0fh		;bit 3,2 = layer0 / bit 1,0 = layer1
	out	dx,al		;画面出力off

	;///////////////////////////////
	;/// FM音源タイマリスタート ////
	;本当は inp(4d8h) & 80h で busy 確認すべきなのだが……
	;
	mov	dx,04d8h	;FM音源アドレスレジスタ
	mov	al,2bh		;アドレス
	out	dx,al		;データ出力
	out	6ch,al		;1us-Wait
	mov	dl,0dah		;FM音源データレジスタ
	mov	al,2ah		;出力値
	out	dx,al		;データ出力
	out	6ch,al		;1us-Wait

	mov	dl,0d8h		;FM音源アドレスレジスタ
	mov	al,27h		;アドレス
	out	dx,al		;データ出力
	out	6ch,al		;1us-Wait
	mov	dl,0dah		;FM音源データレジスタ
	mov	al,2ah		;出力値
	out	dx,al		;データ出力
	ret

	;/////////////////////////////////////////////////////////////
	;パレット設定ルーチン
	;/////////////////////////////////////////////////////////////
	align	4
.setPalette16:
	mov	dx,448h		;CRTC出力レジスタ操作
	mov	al,01h		;
	out	dx,al		;操作ページの設定

	mov	dl,4ah		;CRTC出力レジスタ操作
	mov	al,ah		;操作ページのロード
	out	dx,al		;

	xor	ecx,ecx		;ecx = 0
	mov	dh,0fdh		;パレットレジスタの上位ビット

	align	4
.loop2:
	mov	al,cl		;パレット番号
	mov	dl,90h		;
	out	dx,al

	inc	cl		;パレット番号更新
	mov	si,[ebx]	;パレットデータロード
	add	ebx,byte 2	;アドレス更新

	mov	eax,esi		;パレットデータ
	shl	eax,4		;
	mov	dl,92h		;blue
	out	dx,al

	mov	eax,esi		;パレットデータ
	mov	dl,94h		;Red
	out	dx,al		;

	shr	eax,4		;
	mov	dl,96h		;Green
	out	dx,al		;

	cmp	cl,10h		;終了値 ?
	jne	.loop2
	ret


BITS	16
;==============================================================================
;exit process for TOWNS on 16bit mode
;==============================================================================
proc exit_TOWNS_16
	cmp	b [load_nsdd], 0
	jz	short .no_nsdd
	;
	; [clear] real mode to 32bit mode far call routine
	;
	xor	bx, bx
	xor	dx, dx
	mov	ax, 0c207h
	int	8eh
.no_nsdd:
	;///////////////////////////////
	;reset key BIOS
	;///////////////////////////////
%if (INIT_KEY_BIOS)
	mov	ah,90h
	int	90h
	mov	ax,0501h
	int	90h
%endif

	ret


;==============================================================================
;■データ領域
;==============================================================================
is_emulator	db	0
load_nsdd	db	0

;==============================================================================
;★CRTC 操作テーブル
;==============================================================================
	align	4
TOWNS_CRTC_data:
	;// 24kHzモード 640×400(4bits,FMR)+640×400(4bits)
	dw	0040h, 0320h, 0000h, 0000h, 035fh, 0000h, 0010h, 0000h
	dw	036fh, 009ch, 031ch, 009ch, 031ch, 0040h, 0360h, 0040h
	dw	0360h, 0000h, 009ch, 0000h, 0050h, 0000h, 009ch, 0000h
	dw	0080h, 004ah, 0001h, 0000h, 803fh, 0003h, 0000h, 0188h

	;パレットデータ
TOWNS_PAL_layer0:	;グラフィック画面（手前）
	dw	0000h, 0008h, 0080h, 0088h, 0800h, 0808h, 0880h, 0888h
	dw	0777h, 000fh, 00f0h, 00ffh, 0f00h, 0f0fh, 0ff0h, 0fffh
TOWNS_PAL_layer1:	;コンソール (文字) 画面
	dw	0000h, 000bh, 00b0h, 00bbh, 0b00h, 0b0bh, 0bb0h, 0bbbh
	dw	0888h, 000fh, 00f0h, 00ffh, 0f00h, 0f0fh, 0ff0h, 0fffh

;==============================================================================
;★T-OS のメモリ関連データ
;==============================================================================
	align	4
T_OS_memory_map:
		;sel, base     ,  pages -1, type/level
	;dd	 3ch,        0,       0   , 0000h	;dummy
	dd	100h,0fffc0000h,  256/4 -1, 0a00h	;R/X : boot-ROM
	;dd	108h,0fffc0000h,  256/4 -1, 0000h	;R   : boot-ROM
	dd	120h, 80000000h,  512/4 -1, 0200h	;R/W : VRAM (16/32k)
	dd	128h, 80100000h,  512/4 -1, 0200h	;R/W : VRAM (256)
	dd	130h, 81000000h,  128/4 -1, 0200h	;R/W : Sprite-RAM
	dd	138h,0c2100000h,  264/4 -1, 0200h	;R/W : FONT-ROM,学習RAM
	dd	140h,0c2200000h,    4/4 -1, 0200h	;R/W : Wave-RAM
	dd	148h,0c2000000h,  512/4 -1, 0000h	;R   : OS-ROM
	;dd	11ch, 82000000h, 1024/4 -1, 0200h	;R/W : H-VRAM / 2 layer
	dd	11ch, 82000000h, 8704/4 -1, 0200h	;R/W : H-VRAM / 2 layer
	dd	124h, 83000000h, 1024/4 -1, 0200h	;R/W : H-VRAM / 1 layer
	dd	12ch, 84000000h, 1024/4 -1, 0200h	;R/W : VRAM??
	dd	0	;end of data
	;
	; "11ch" is separate VRAM mapped "0.0MB to 0.5MB" and "8.0MB to 8.5MB".
	; RUN386.EXE is mapped 16MB for "11ch, 124h, 12ch" selector.
	;
	align	4
T_OS_memory_map_386sx:
		;sel, base     ,  pages -1, type/level
	dd	100h, 00fc0000h,  256/4 -1, 0a00h	;R/X : boot-ROM
	;dd	108h, 00fc0000h,  256/4 -1, 0000h	;R   : boot-ROM
	dd	120h, 00a00000h,  512/4 -1, 0200h	;R/W : VRAM (16/32k)
	dd	128h, 00b00000h,  512/4 -1, 0200h	;R/W : VRAM (256)
	dd	130h, 00c00000h,  128/4 -1, 0200h	;R/W : Sprite-RAM
	dd	138h, 00f00000h,  264/4 -1, 0200h	;R/W : FONT-ROM,学習RAM
	dd	140h, 00f80000h,    4/4 -1, 0200h	;R/W : Wave-RAM
	dd	148h, 00e00000h,  512/4 -1, 0000h	;R   : OS-ROM
	dd	0	; Special thanks to @RyuTakegami

	align	4
T_OS_selector_alias:
		;ORG, alias, type/level
	dd	100h,  108h,  0000h	;boot-ROM
	dd	120h,  104h,  0200h	;VRAM (16/32k)
	dd	128h,  10ch,  0200h	;VRAM (256)
	dd	130h,  114h,  0200h	;Sprite-RAM

	dd	120h,   48h,  0200h	;不明な alias / VRAM(16/32K)
	dd	120h,   1ch,  0200h	;不明な alias / VRAM(16/32K)
	dd	0	;end of data


segment	code
