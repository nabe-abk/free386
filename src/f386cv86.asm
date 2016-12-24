;******************************************************************************
;　V86 ←→ Protect 低レベル連携ルーチン / Free386
;******************************************************************************
;[TAB=8]
;
; 2001/02/15　Free386.asm から分離
;
;
;
%include	"nasm_abk.h"		;NASM 用ヘッダファイル
%include	"macro.asm"		;マクロ部の挿入
%include	"f386def.inc"		;定数部の挿入

%include	"free386.inc"		;外部変数


;******************************************************************************
;■グローバルシンボル宣言
;******************************************************************************

public	setup_cv86		;call v86 の初期設定
public	clear_mode_data		;モード切替えデータの初期化

public	call_V86_int		;int 呼び出し
public	call_V86_int21		;int 21h 呼び出し

public	call_V86		;汎用的なな呼び出しルーチン (call して使用)
public	rint_labels_adr		;リアルモード割り込みフックルーチン先頭アドレス

public	call_v86_ds
public	call_v86_es
public	ISTK_nest

segment	text align=4 class=CODE use16
;******************************************************************************
;■初期化コード
;******************************************************************************
;==============================================================================
;■V86←→Protect連携ルーチンのセットアップ
;==============================================================================
;ISTK_v86_size	equ	200h	;モード切り換え時、V86 側スタック保証サイズ
;ISTK_prot_size	equ	200h	;モード切り換え時、Protect 側スタック保証サイズ
;INT_nests	equ	4	;割り込みネスト数 (※Prot / V86 それぞれにつき)
;
BITS	16
setup_cv86:
	;//////////////////////////////////////////////////
	;リルアモード割り込みフックルーチン生成用メモリ取得
	;//////////////////////////////////////////////////
	mov	ax,Real_Vectors *4	;フックルーチン生成用メモリ
	call	heap_malloc		;上位メモリ割り当て
	mov	[rint_labels_adr],di	;save
	mov	dx,di			;dx に
	add	dx,byte 3		;hook ラベルと retラベル のずれを加算
	mov	[rint_labels_top],dx	;

	;フックルーチンの生成
	mov	bl,0e8h			;call命令
	mov	bh, 90h			;NOP 命令
	mov	cx,Real_Vectors		;int の数
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

	;//////////////////////////////////////////////////
	;モード切り換え時用、一時スタックメモリ取得
	;//////////////////////////////////////////////////
	mov	ax,ISTK_size * ISTK_nest_max	;V86 <-> Prot stack
	call	stack_malloc			;下位メモリ割り当て
	mov	[ISTK_adr    ],di		;記録
	mov	[ISTK_adr_org],di		;初期値
	ret

BITS	32
;------------------------------------------------------------------------------
;★V86←→Protect モード切り換えデータの初期化
;------------------------------------------------------------------------------
	align	4
clear_mode_data:
	pushfd
	cli
	push	eax
	mov	eax,[ISTK_adr_org]		;初期値ロード
	mov	[ISTK_adr], eax			;セーブ

	mov	eax,[int_buf_adr_org]		;初期値ロード
	mov	[int_buf_adr],eax		;セーブ

	xor	eax, eax
	mov	[ISTK_nest],eax			;nestカウンタ初期化
	pop	eax
	popfd
	ret


;******************************************************************************
;■V86 モードの割り込みルーチン呼び出し (from Protect mode)
;******************************************************************************
;	引数	+00h d Int_No * 4
;
	align	4
call_V86_int21:
	push	d (21h * 4)		;ds : ベクタ番号 ×4
call_V86_int:
	sub	esp, 0ch		;es --> gs
	push	eax

	push	ds
	push	es
	LOAD_F386_ds			;データセグメント

	cli
	mov	eax,DOSMEM_sel		;DOSメモリ読み書き用セレクタ
	mov	 es,eax			;gs にロード
	mov	eax,[esp + 4*6]		;引数（ベクタ番号*4）を取得
	mov	eax,[es:eax]		;V86 割り込みベクタロード
	mov	[call_v86_adr],eax	;呼び出しアドレスセーブ

	pop	es
	pop	ds

	mov	eax, [cs:v86_cs]
	mov	[esp+04h], eax		;V86 ds
	mov	[esp+08h], eax		;V86 es
	mov	[esp+0ch], eax		;V86 fs
	mov	[esp+10h], eax		;V86 gs

	mov	eax, [cs:call_v86_adr]
	xchg	[esp], eax		;[esp]=呼び出し先, eax=オリジナル
	call	call_V86

	; フラグ設定
	pushfd
	push	eax
	mov	eax, [esp+4]
	mov	[esp+24h], eax

	pop	eax
	add	esp, 18h		;スタック除去
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
	mov	[call_v86_adr],eax	;呼び出しアドレスセーブ

	push	ss			;現在のスタック
	pop	gs			;gs に設定

	lss	esp,[VCPI_stack_adr]	;専用スタックロード
	push	d [gs:esi+12]		;** V86 gs
	push	d [gs:esi+ 8]		;** V86 fs
	push	d [gs:esi   ]		;** V86 ds
	push	d [gs:esi+ 4]		;** V86 es
	push	d [v86_cs]		;** V86 ss

	call	alloc_ISTK_32
	push	eax			;** V86 sp
	pushf				;eflags
	push	d [v86_cs]		;** V86 CS を記録
	push	d (offset .in86)	;** V86 IP を記録

	mov	ax,0de0ch		;VCPI function 0ch / to V86 mode
	VCPI_function			;VCPI far call


;--------------------------------------------------------------------
;・V86側
;--------------------------------------------------------------------
BITS	16
	align	4
.in86:
	push	d [cs:save_ss]		;呼び出し側の ss/esp
	push	d [cs:save_esp]		;

	mov	eax,[cs:save_eax]	;eax の値復元
	mov	esi,[cs:save_esi]	;eax の値復元

	push	w (-1)			;mark / iret,retf両対応のため
	pushf				;flag save for INT
	call	far [cs:call_v86_adr]	;目的ルーチンのコール

	cli
	mov	[cs:call_v86_ds],ds	;ds セーブ
	mov	ds,[cs:v86_cs]		;V86時 ds
	mov	[call_v86_es],es	;es セーブ
	mov	[call_v86_fs],fs	;fs セーブ
	mov	[call_v86_gs],gs	;gs セーブ

	mov	[save_eax],eax		;eax セーブ
	mov	[save_esi],esi		;esi セーブ
	pushf
	pop	w [call_v86_flags]	;flags セーブ

	pop	ax			;flagsが取り除かれてるか？
	cmp	ax,-1
	jz	.pop_skip		;flagsがなければskip
	pop	ax
.pop_skip:
	pop	d [save_esp]		;Protect mode esp
	pop	d [save_ss]		;Protect mode ss

	mov	w [to_PM_EIP],offset .retPM	;戻りラベル

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
	mov	 ds,eax			;gs にロード

	lss	esp,[save_esp]		;スタック復元
	call	free_ISTK_32

	;引数	+08h	V86 ds
	;	+0ch	V86 es
	;	+10h	V86 fs
	;	+14h	V86 gs
	mov	eax,[call_v86_ds]	;V86 ds 戻り値
	mov	esi,[call_v86_es]	;V86 es
	mov	[esp + 4*4 + 08h],eax	;スタックにセーブ
	mov	[esp + 4*4 + 0ch],esi	;
	mov	eax,[call_v86_fs]	;V86 fs
	mov	esi,[call_v86_gs]	;V86 gs
	mov	[esp + 4*4 + 10h],eax	;スタックにセーブ
	mov	[esp + 4*4 + 14h],esi	;

	pop	gs			;
	pop	fs			;セレクタ復元
	pop	es			;
	pop	ds			;

	pushfd		;flags

	mov	eax,[cs:call_v86_flags]	;V86 時フラグ
	and	eax,    00cffh		;IF/IOPL 以外取り出し
	and	w [esp],0f300h		;IF/IOPL など取り出し
	or	  [esp],ax		;結果のフラグを混ぜる

	mov	eax,[cs:save_eax]	;eax 復元
	mov	esi,[cs:save_esi]	;esi 復元

	popfd
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

	mov   w [to_PM_EIP],offset .32	;呼び出しラベル

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
	cli
	mov	eax,F386_ds		;
	mov	 ds,eax			;ds ロード
	mov	 es,eax			;
	mov	 fs,eax			;
	mov	 gs,eax			;

	lss	esp, [ISTK_adr]		;ss:esp を設定
	call	alloc_ISTK_32		;DS復元後

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

	call	free_ISTK_32		;スタック開放

	mov	eax,[v86_cs]		;V86時 cs,ds
	lss	esp,[VCPI_stack_adr]	;専用スタックロード
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
	VCPI_function			;VCPI far call


;******************************************************************************
;■ISTKサブルーチン 32bit
;******************************************************************************
;==============================================================================
;■ISTKからスタックメモリを確保
;==============================================================================
	align	4
alloc_ISTK_32:
	pushf
	cli
	mov	eax, [ISTK_nest]
	cmp	eax, ISTK_nest_max
	jae	short .error_exit

	mov	eax, [ISTK_adr]
	inc	d [ISTK_nest]
	sub	d [ISTK_adr], ISTK_size

	push	eax
	mov	eax, [ISTK_nest]
	shl	eax, INT_BUF_sizebits
	add	eax, [int_buf_adr_org]
	mov	[int_buf_adr],eax
	pop	eax

	popf
	ret

.error_exit:
	call	clear_mode_data
	F386_end	26h		; ISTK Overflow

;==============================================================================
;■ISTKメモリを開放
;==============================================================================
	align	4
free_ISTK_32:
	pushf
	push	eax
	cli

	mov	eax, [ISTK_nest]
	test	eax, eax
	jz	short .error_exit

	dec	d [ISTK_nest]
	add	d [ISTK_adr], ISTK_size

	mov	eax, [ISTK_nest]
	shl	eax, INT_BUF_sizebits
	add	eax, [int_buf_adr_org]
	mov	[int_buf_adr],eax

	pop	eax
	popf
	ret

.error_exit:
	call	clear_mode_data
	F386_end	27h		; ISTK Underflow


BITS	32
;******************************************************************************
;■データ
;******************************************************************************
segment	data align=16 class=CODE use16
group	comgroup text data
;------------------------------------------------------------------------------
save_eax	dd	0		;モード切り換え時のレジスタセーブ用
save_esi	dd	0		;
save_esp	dd	0		;あくまで一時領域
save_ss		dd	0		;

call_v86_ds	dw	0,0		;
call_v86_es	dw	0,0		;V86 のルーチンコール後の
call_v86_fs	dw	0,0		; 各レジスタの値
call_v86_gs	dw	0,0		;
call_v86_flags	dw	0,0		;

call_v86_adr	dd	0		;V86 / 呼び出す CS:IP

ISTK_adr	dd	0		;V86←→Protectモード切替時用のスタック
		dd	F386_ds		;セレクタ
ISTK_adr_org	dd	0
ISTK_nest	dd	0

rint_labels_top	dd	0		;↓+3/ 戻りオフセットから int番号算出用
rint_labels_adr	dd	0		;リアルモード割り込みフックルーチン
					;　作成領域へのポインタ

;******************************************************************************
;******************************************************************************
