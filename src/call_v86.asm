;******************************************************************************
;　V86 ←→ Protect 低レベル連携ルーチン / Free386
;******************************************************************************
;[TAB=8]
;
%include	"macro.inc"
%include	"f386def.inc"

%include	"free386.inc"
%include	"memory.inc"

;******************************************************************************
;■グローバルシンボル宣言
;******************************************************************************

global	setup_cv86
global	clear_mode_data

global	call_V86_int
global	call_V86_int21
global	call_V86_HARD_int

global	call_V86
global	call_V86_ds
global	call_V86_es

global	callf32_from_V86	; use by int 21h ax=250dh and towns.asm

global	rint_labels_adr

;******************************************************************************
segment	text class=CODE align=4 use16
;******************************************************************************
;■初期化コード
;******************************************************************************
;==============================================================================
;■V86←→Protect連携ルーチンのセットアップ
;==============================================================================
proc32 setup_cv86
	;//////////////////////////////////////////////////
	;リルアモード割り込みフックルーチン生成用メモリ取得
	;//////////////////////////////////////////////////
	mov	ax,IntVectors *4	;フックルーチン生成用メモリ
	call	heap_malloc		;上位メモリ割り当て
	mov	[rint_labels_adr],di	;save
	mov	dx,di			;dx に
	add	dx,byte 3		;hook ラベルと retラベル のずれを加算
	mov	[rint_labels_top],dx	;

	;フックルーチンの生成
	mov	bl,0e8h			;call命令
	mov	bh, 90h			;NOP 命令
	mov	cx,IntVectors		;int の数
	mov	si,offset int_V86	;呼び出しラベル
	mov	bp,4			;加算値
	mov	ax,si			;ax = 呼び出しアドレス

	align	4
	;e8 xxxx	call int_buf
	;90		nop
	;を 256 個並べる（int hook用）
.loop:
	mov	[di+3],bh		;NOP
	mov	[di  ],bl		;call
	sub	ax,dx			;相対アドレス算出
	mov	[di+1],ax		;<r_adr>
	add	di,bp			;int ラベル
	add	dx,bp			;call 時 stack に積まれるアドレス
	mov	ax,si			;ax = 呼び出しアドレス
	loop	.loop

	ret

BITS	32
;------------------------------------------------------------------------------
;★V86←→Protect モード切り換えデータの初期化
;------------------------------------------------------------------------------
	align	4
clear_mode_data:
	ret


;******************************************************************************
;■V86 モードの割り込みルーチン呼び出し (from Protect mode)
;******************************************************************************
;	引数	+00h d Interrupt number
;
	align	4
call_V86_int21:
	push	d 21h			;ベクタ番号
call_V86_int:
	sub	esp, 10h		;es --> gs
	push	eax

	push	ds
	push	es

	push	d F386_ds
	pop	ds

	cli
	mov	eax,DOSMEM_sel		;DOSメモリ読み書き用セレクタ
	mov	  es,ax			;es にロード
	mov	eax,[esp + 4*7]		;引数（ベクタ番号*4）を取得
	mov	eax,[es:eax*4]		;V86 割り込みベクタロード
	mov	[call_V86_adr],eax	;呼び出しアドレスセーブ

	pop	es
	pop	ds

	mov	eax, [cs:V86_cs]
	mov	[esp+04h], eax		;V86 ds
	mov	[esp+08h], eax		;V86 es
	mov	[esp+0ch], eax		;V86 fs
	mov	[esp+10h], eax		;V86 gs

	mov	eax, [cs:call_V86_adr]
	xchg	[esp], eax		;[esp]=呼び出し先, eax=オリジナル
	call	call_V86

	; Carryフラグ設定
	pushfd
	push	eax

	mov	eax, [esp+4]
	and	b [esp+28h], 0feh
	and	al, 01h
	or	b [esp+28h], al

	pop	eax
	add	esp, 1ch		;スタック除去
	iret


;******************************************************************************
;■V86モードの割り込みルーチン呼び出し (ハードウェア割り込み用)
;******************************************************************************
;	引数	+00h d Interrupt number
;
	align	4
call_V86_HARD_int:
	xchg	[esp], esi		;esi = int番号
	push	eax
	push	es

	mov	eax,[cs:V86_cs]
	push	eax			;gs
	push	eax			;fs
	push	eax			;es
	push	eax			;ds

	mov	eax,DOSMEM_sel		;DOSメモリ読み書き用セレクタ
	mov	  es,ax
	push	d [es:esi*4]		;V86割り込みベクタ

	call	call_V86

	add	esp, 14h		;スタック除去

	pop	es
	pop	eax
	pop	esi
	iret


;******************************************************************************
;■V86コール汎用サブルーチン
;******************************************************************************
;・このルーチンは「call」して使用する
;・V86 コール時の セグメントレジスタの値を保存する
;・任意のアドレスを呼び出せる
;・フラグは基本的にV86側で、callした戻り値をセット
;
;引数	+00h	戻りアドレス
;	+04h	call adress / cs:ip
;	+08h	V86 ds
;	+0ch	V86 es
;	+10h	V86 fs
;	+14h	V86 gs
;
	align	4
call_V86:
	push	ds	;1	esp によるスタック参照に注意！
	push	es	;2
	push	fs	;3
	push	gs	;4

	push	d (F386_ds)		;データセグメント
	pop	ds			;ds にロード

	cli
	mov	[save_eax],eax		;eax保存
	mov	[save_esi],esi		;esi
	mov	[save_esp],esp
	mov	[save_ss] ,ss

	mov	eax,[esp + 4*4 +4]	;呼び出しアドレスロード
	lea	esi,[esp + 4*4 +8]	;V86 call パラメータブロック
	mov	[call_V86_adr],eax	;呼び出しアドレスセーブ

	push	ss			;現在のスタック
	pop	gs			;gs に設定

	lss	esp,[VCPI_stack_adr]	;専用スタックロード
	push	d [gs:esi+12]		;** V86 gs
	push	d [gs:esi+ 8]		;** V86 fs
	push	d [gs:esi   ]		;** V86 ds
	push	d [gs:esi+ 4]		;** V86 es
	push	d [V86_cs]		;** V86 ss

	call	alloc_sw_stack_32
	push	eax			;** V86 sp
	pushf				;eflags
	push	d [V86_cs]		;** V86 CS を記録
	push	d (offset .in86)	;** V86 IP を記録

	mov	ax,0de0ch		;VCPI function 0ch / to V86 mode
	call 	far [VCPI_entry]	;VCPI far call


;--------------------------------------------------------------------
;・V86側
;--------------------------------------------------------------------
BITS	16
	align	4
.in86:
	push	d [cs:save_ss]		;呼び出し側の ss/esp
	push	d [cs:save_esp]		;

	mov	eax,[cs:save_eax]	;eax の値復元
	mov	esi,[cs:save_esi]	;esi の値復元

	push	w (-1)			;mark / iret,retf両対応のため
	pushf				;flag save for INT
	call	far [cs:call_V86_adr]	;目的ルーチンのコール

	cli
	mov	[cs:call_V86_ds],ds	;ds セーブ
	mov	ds,[cs:V86_cs]		;V86時 ds
	mov	[call_V86_es],es	;es セーブ
	mov	[call_V86_fs],fs	;fs セーブ
	mov	[call_V86_gs],gs	;gs セーブ

	mov	[save_eax],eax		;eax セーブ
	mov	[save_esi],esi		;esi セーブ
	pushf
	pop	w [call_V86_flags]	;flags セーブ

	pop	ax			;flagsが取り除かれてるか？
	cmp	ax,-1
	jz	.pop_skip		;flagsがなければskip
	pop	ax
.pop_skip:
	pop	d [save_esp]		;Protect mode esp
	pop	d [save_ss]		;Protect mode ss

	mov	d [to_PM_EIP],offset .retPM	;戻りラベル

	mov	esi,[to_PM_data_ladr]	;モード切替え用構造体アドレス
	mov	ax,0de0ch		;to プロテクトモード
	int	67h			;VCPI call

BITS	32
;--------------------------------------------------------------------
;・プロテクトモード側
;--------------------------------------------------------------------
	align	4
.retPM:
	mov	eax,F386_ds		;ds
	mov	  ds,ax			;gs にロード

	lss	esp,[save_esp]		;スタック復元
	call	free_sw_stack_32

	;引数	+08h	V86 ds
	;	+0ch	V86 es
	;	+10h	V86 fs
	;	+14h	V86 gs
	mov	eax,[call_V86_ds]	;V86 ds 戻り値
	mov	esi,[call_V86_es]	;V86 es
	mov	[esp + 4*4 + 08h],eax	;スタックにセーブ
	mov	[esp + 4*4 + 0ch],esi	;
	mov	eax,[call_V86_fs]	;V86 fs
	mov	esi,[call_V86_gs]	;V86 gs
	mov	[esp + 4*4 + 10h],eax	;スタックにセーブ
	mov	[esp + 4*4 + 14h],esi	;

	pop	gs			;
	pop	fs			;セレクタ復元
	pop	es			;
	pop	ds			;

	mov	eax,[cs:save_eax]	;eax 復元
	mov	esi,[cs:save_esi]	;esi 復元

	bt	d [cs:call_V86_flags],0	;V86時 Carryフラグ設定
	ret


;******************************************************************************
;■V86 からプロテクトモード割り込みルーチンの呼び出し
;******************************************************************************
BITS	16
	align	4
int_V86:
	push	ds	;4
	push	es	;3
	push	fs	;2
	push	gs	;1

	push	cs			;
	pop	ds			;ds 設定
	mov	[save_eax],eax		;eax セーブ
	mov	[save_esi],esi		;esi
	mov	[save_esp],esp
	mov	[save_ss] ,ss

	;-------------------------------
	;int 番号の算出
	;-------------------------------
	mov	ax,ss			;
	mov	fs,ax			;fs:si = ss:sp
	mov	si,sp			;

	mov	ax,[fs:si + 2*4]	;call 元アドレス
	sub	ax,[rint_labels_top]	;登録番号 0 から (CPU Int 処理と同じ
	shr	ax,2			;4 で割る         int.asm 参照)
	mov	[.int_no], al		;プロテクト時の呼び出し番号として記録

	mov   d [to_PM_EIP],offset .32	;呼び出しラベル

	mov	esi,[to_PM_data_ladr]	;モード切替え構造体
	mov	ax,0de0ch		;to プロテクトモード
	int	67h			;VCPI call


	align	4
	;*** プロテクトモードからの復帰ラベル ******
.ret_PM:
	mov	eax,[save_eax]		;eax 復元
	mov	esi,[save_esi]		;esi

	pop	gs
	pop	fs
	pop	es
	pop	ds
	add	sp,byte 2		;call の戻りスタック除去
	iret



BITS	32
;--------------------------------------------------------------------
;・プロテクトモード
;--------------------------------------------------------------------
	align	4
.32:
	mov	eax,F386_ds		;
	mov	  ds,ax			;ds ロード
	mov	  es,ax			;
	mov	  fs,ax			;
	mov	  gs,ax			;

	lss	esp,[PM_stack_adr]	;専用スタックロード
	;call	alloc_sw_stack_32	;スタック領域確保

	push	d [save_ss]		;リアルモードスタック
	push	d [save_esp]

	mov	eax,[save_eax]		;eax 復元
	mov	esi,[save_esi]		;esi

	push	ds
	db	0cdh			;int 命令
.int_no	db	 00h
	pop	ds

	cli
	mov	[save_eax], eax		;eax 保存
	mov	[save_esi], esi		;esi

	pop	d [save_esp]		;リアルモードスタック
	pop	d [save_ss]

	;call	free_sw_stack_32	;スタック開放

	mov	eax,[V86_cs]		;V86時 cs,ds
	push	eax			;** V86 gs
	push	eax			;** V86 fs
	push	eax			;** V86 ds
	push	eax			;** V86 es
	push	d [save_ss ]		;** V86 ss
	push	d [save_esp]		;** V86 sp
	pushfd				;eflags
	push	eax			;** V86 CS を記録
	push	d (offset .ret_PM)	;** V86 IP を記録

	mov	ax,0de0ch		;VCPI function 0ch / to V86 mode
	call 	far [VCPI_entry]	;VCPI far call


;******************************************************************************
; far call protect mode routeine from V86
;******************************************************************************
BITS	16
	align	4
callf32_from_V86:
	; retf address	;     = 4
	push	ds	; 2*4 = 8
	push	es
	push	fs
	push	gs
	push	eax	; 4*2 = 8
	push	esi

	push	cs
	pop	ds

	cli
	push	bp	; = 2
	mov	bp, sp
	mov	eax, [bp + 16h]
	mov	[cs:cf32_target_eip], eax
	mov	eax, [bp + 1ah]
	mov	[cs:cf32_target_cs],  eax
	pop	bp

	xor	eax, eax
	mov	ax, ss
	mov	[cf32_ss16],  eax	;save SS
	shl	eax, 4
	add	eax, esp
	mov	[cf32_esp32], eax	;linear adddress of ss:esp

	mov   d [to_PM_EIP],offset .32	; jmp to
	mov	esi, [to_PM_data_ladr]
	mov	ax,0de0ch
	int	67h			; VCPI call


	align 4
BITS	32
.32:
	mov	eax,F386_ds		;
	mov	  ds,ax			;ds ロード
	mov	  es,ax			;
	mov	  fs,ax			;
	mov	  gs,ax			;
	lss	esp, [cf32_esp32]	;ss:esp を設定

	pop	esi
	pop	eax
	call	far [cf32_target_eip]
	push	eax
	push	esi
	mov	esi, esp

	mov	eax,[V86_cs]		;V86時 cs,ds
	push	eax			;** V86 gs
	push	eax			;** V86 fs
	push	eax			;** V86 ds
	push	eax			;** V86 es

	push	d [cf32_ss16]		;** V86 ss
	push	eax			;** V86 sp // dummy
	pushfd				;eflags
	push	eax			;** V86 CS
	push	d (offset .ret_PM)	;** V86 IP

	mov	eax, [cf32_ss16]
	shl	eax, 4
	sub	esi, eax
	mov	[esp + 0ch], esi	; Fix V86 sp

	mov	ax,0de0ch		;VCPI function 0ch / to V86 mode
	call 	far [VCPI_entry]	;VCPI far call


	align	4
BITS	16
.ret_PM:
	pop	esi
	pop	eax

	pop	gs
	pop	fs
	pop	es
	pop	ds
	retf



BITS	32
;******************************************************************************
;■データ
;******************************************************************************
segment	data class=DATA align=4
;------------------------------------------------------------------------------
save_eax	dd	0		;temporary
save_esi	dd	0		;
save_esp	dd	0		;
save_ss		dd	0		;

call_V86_ds	dw	0,0		;
call_V86_es	dw	0,0		;V86 のルーチンコール後の
call_V86_fs	dw	0,0		; 各レジスタの値
call_V86_gs	dw	0,0		;
call_V86_flags	dw	0,0		;

call_V86_adr	dd	0		;V86 / 呼び出す CS:IP

	; Real mode interrupt hook routines, for call to 32bit from V86.
rint_labels_adr	dd	0
rint_labels_top	dd	0		; rint_labels_adr +3


cf32_ss16	dd	0		;
cf32_esp32	dd	0		;in 32bit linear address
		dd	DOSMEM_sel	;for lss
cf32_target_eip	dd	0		;call target entry
cf32_target_cs	dd	0		;

;******************************************************************************
;******************************************************************************
