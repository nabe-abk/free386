;******************************************************************************
;　Free386	割り込み処理ルーチン
;******************************************************************************
;[TAB=8]
;
; 2001/01/18	ファイルを分離
; 2001/02/26	オブジェクトファイルを分離
;
%include	"nasm_abk.h"		;NASM 用ヘッダファイル
%include	"macro.asm"		;マクロ部の挿入
%include	"f386def.inc"		;定数部の挿入

%include	"start.inc"		;動作オプション
%include	"f386sub.inc"		;Free386 用サブルーチン
%include	"f386seg.inc"		;セレクタ/ページングルーチン
%include	"f386cv86.inc"		;V86 ←→ Protect 低レベル連携ルーチン
%include	"free386.inc"		;Free386 本体変数

;//////////////////////////////////////////////////////////////////////////////
;■グローバルシンボル宣言
;//////////////////////////////////////////////////////////////////////////////

public		PM_int_00h
public		PM_int_dummy
public		DOS_int_list
public		intr_M0
public		intr_S0


;//////////////////////////////////////////////////////////////////////////////
;■割り込み処理ルーチン
;//////////////////////////////////////////////////////////////////////////////
segment	text align=4 class=CODE use16
BITS	32
;------------------------------------------------------------------------------
;★ダミーの割り込みハンドラ
;------------------------------------------------------------------------------
;	DOS のハンドラへ chain する
;
	align	4
PM_int_dummy:
	push	ebx
	push	ds

	mov	ds ,[esp+0ch]		;CS
	mov	ebx,[esp+08h]		;EIP ロード
	movzx	ebx,b [ebx-1]		;int 番号をロード
	pop	ds

%if INT_HOOK
	xchg	[esp], ebx		;ebx復元
	call	register_dump_from_int	;safe
	xchg	[esp], ebx		;ebx=int番号
%endif
	shl	ebx,2			;4 倍する

	xchg	[esp],ebx		;ebx復元 と 呼び出しベクタ設定
	jmp	call_V86_int


;------------------------------------------------------------------------------
;★インテル予約ＣＰＵ例外（int 00 - 1f）
;------------------------------------------------------------------------------
	align	4
PM_int_00h:	clc
		push	eax
		call	cpu_int
PM_int_top:	nop

PM_int_01h:	clc
		push	eax
		call	cpu_int
		nop

PM_int_02h:	clc
		push	eax
		call	cpu_int
		nop

PM_int_03h:	clc
		push	eax
		call	cpu_int
		nop

PM_int_04h:	clc
		push	eax
		call	cpu_int
		nop

PM_int_05h:	clc
		push	eax
		call	cpu_int
		nop

PM_int_06h:	clc
		push	eax
		call	cpu_int
		nop

PM_int_07h:	clc
		push	eax
		call	cpu_int
		nop

PM_int_08h:	clc
		nop
		jmp	NEAR double_fault
		nop

PM_int_09h:	clc
		nop
		call	cpu_int
		nop

PM_int_0ah:	stc
		nop
		call	cpu_int_with_error_code
		nop

PM_int_0bh:	stc
		nop
		call	cpu_int_with_error_code
		nop

PM_int_0ch:	clc
		nop
		jmp	NEAR stack_fault	;スタック例外
		nop

PM_int_0dh:	stc
		nop
		call	cpu_int_with_error_code
		nop

PM_int_0eh:	stc
		nop
		call	cpu_int_with_error_code
		nop

PM_int_0fh:	clc
		push	eax
		call	cpu_int
		nop

PM_int_10h:	clc
		push	eax
		call	cpu_int
		nop

PM_int_11h:	stc
		nop
		call	cpu_int_with_error_code
		nop

PM_int_12h:	clc
		push	eax
		call	cpu_int
		nop

PM_int_13h:	clc
		push	eax
		call	cpu_int
		nop

PM_int_14h:	clc
		push	eax
		call	cpu_int
		nop

PM_int_15h:	clc
		push	eax
		call	cpu_int
		nop

PM_int_16h:	clc
		push	eax
		call	cpu_int
		nop

PM_int_17h:	clc
		push	eax
		call	cpu_int
		nop

PM_int_18h:	clc
		push	eax
		call	cpu_int
		nop

PM_int_19h:	clc
		push	eax
		call	cpu_int
		nop

PM_int_1ah:	clc
		push	eax
		call	cpu_int
		nop

PM_int_1bh:	clc
		push	eax
		call	cpu_int
		nop

PM_int_1ch:	clc
		push	eax
		call	cpu_int
		nop

PM_int_1dh:	clc
		push	eax
		call	cpu_int
		nop

PM_int_1eh:	stc
		nop
		call	cpu_int_with_error_code
		nop

PM_int_1fh:	clc
		push	eax
		call	cpu_int

	;	+0ch	eflags
	;	+08h	cs
	;	+04h	eip
	;stack	+00h	error code

	align	4
double_fault:
stack_fault:
	lss	esp,[cs:PM_stack_adr]		;スタックポインタロード
	push	d -1				; eflags
	push	d -1				; eip
	push	d -1				; cs
	push	d 0				; error code
	push	d (offset PM_int_0ch +7)	;call 元の代わり
	push	ds
	push	eax
	jmp	short view_int

	align	4
cpu_int:
cpu_int_with_error_code:
	cld
	push	ds
	push	eax	; for register_dump_fault	;safe
	pushf

	mov	eax, F386_ds
	mov	ds, eax

	mov	eax, esp
	sub	eax, 1ch
	mov	[dump_orig_esp],esp
	mov	eax, ss
	mov	[dump_orig_ss] ,eax

	; スタックの安全性チェック
	verw	ax
	jnz	short .load_stack	; ss に書き込みできない
	test	eax, eax
	jz	short .load_stack	; ss=0
	lsl	eax, eax		; eax = セレクタ上限
	cmp	esp, eax 		; esp がセレクタ上限を超えてない
	jbe	short .safe
.load_stack:
	lss	esp,[cs:PM_stack_adr]	;安全なスタックポインタロード
	xor	eax, eax
	dec	eax
	push	eax				; eflags
	push	eax				; eip
	push	eax				; cs
	push	eax				; error code
	push	d (offset PM_int_1fh +7)	; call 元の代わり
	push	ds
	push	eax
	clc
	pushf
.safe:
	popf

view_int:
	mov	eax, F386_ds
	mov	ds, eax

	jc	short .step		; エラーコードが正しい
	mov	d [esp+0ch], -1		; 特殊エラーコード
.step:
	;発生 int 番号算出
	mov	eax,[esp+8]		;call元アドレス
	sub	eax,offset PM_int_top	;int 00h との差
	shr	eax,3			;1/8 すると eax = Int 番号
	mov	[esp+8],eax		;int 番号保存
	call	register_dump_fault	;ダンプ表示	;safe

	;スタックポインタロード
	lss	esp,[cs:PM_stack_adr]

	mov	al,CPU_Fault		;プログラム エラーコード記録
	jmp	END_program		;プログラム終了


;------------------------------------------------------------------------------
;★ハードウェア割り込み (INTR)
;------------------------------------------------------------------------------
%if (enable_INTR)

	align	4
intr_M0:	call	INTR_intM		;マスタ側
intr_Mtop:	db	90h,90h,90h
intr_M1:	call	INTR_intM
		db	90h,90h,90h
intr_M2:	call	INTR_intM
		db	90h,90h,90h
intr_M3:	call	INTR_intM
		db	90h,90h,90h
intr_M4:	call	INTR_intM
		db	90h,90h,90h
intr_M5:	call	INTR_intM
		db	90h,90h,90h
intr_M6:	call	INTR_intM
		db	90h,90h,90h
intr_M7:	call	INTR_intM
		db	90h,90h,90h

intr_S0:	call	INTR_intS		;スレーブ側
intr_Stop:	db	90h,90h,90h
intr_S1:	call	INTR_intS
		db	90h,90h,90h
intr_S2:	call	INTR_intS
		db	90h,90h,90h
intr_S3:	call	INTR_intS
		db	90h,90h,90h
intr_S4:	call	INTR_intS
		db	90h,90h,90h
intr_S5:	call	INTR_intS
		db	90h,90h,90h
intr_S6:	call	INTR_intS
		db	90h,90h,90h
intr_S7:	call	INTR_intS
		db	90h,90h,90h

	;///////////////////////////////////////////////
	;ハードウェア割り込み（マスタ側）
	;///////////////////////////////////////////////
INTR_intM:
%if (INTR_MASTER > 1fh)
	push	eax
	mov	eax,[esp+4]				;呼び元アドレス
	sub	eax,(offset intr_Mtop) - INTR_MASTER*8	;先頭との差
							;   + INTR_number*8
	shr	eax,1					;eax = int番号*4
	mov	[esp+4],eax				;int番号*4 記録

	pop	eax			;eax 復元
	jmp	call_V86_HARD_int	;V86 ルーチンコール

%else	;*** CPU 割り込みと被っている ******************
	push	eax
	push	edx

	mov	edx,[esp+8]
	sub	edx,offset intr_Mtop
	shr	edx,3			;edx = IRQ番号

	mov	al,0bh			;ISR 読み出しコマンド
	out	I8259A_ISR_M, al	;8259A に書き込み
	in	al, I8259A_ISR_M	;サービスレジスタ読み出し
	bt	eax,edx			;ハードウェエ割り込み？
	jnc	.CPU_int		;bit が 0 なら CPU割り込み

	lea	eax,[edx*4 + INTR_MASTER*4]	;eax = INT番号 *4
	mov	edx,[cs:intr_table + eax*2 +4]	;edx = 呼び出しselector
	test	edx,edx				;0?
	jz	.dos_chain			;if 0 jmp

	;/// 登録してある割り込みを呼び出し ///
	mov	eax,[cs:intr_table + eax*2]	;offset

	mov	[esp+8],edx		;セレクタ
	xchg	[esp+4],eax		;eax 復元 と オフセット記録
	pop	edx
	retf				;割り込みルーチン呼び出し


	align	4
.dos_chain:
	mov	[esp+8],eax		;呼び出しINT番号として記録
	pop	edx
	pop	eax
	jmp	call_V86_HARD_int	;V86 ルーチンコール


	align	4
.CPU_int:
	lea	eax,[PM_int_00h +INTR_MASTER*8 + edx*8]	;CPU例外 Address
	mov	[esp+8],eax				;セーブ

	pop	edx
	pop	eax
	ret				;CPU 例外呼び出し
%endif

	;///////////////////////////////////////////////
	;ハードウェア割り込み（スレーブ側）
	;///////////////////////////////////////////////
	align	4
INTR_intS:
%if (INTR_SLAVE > 1fh)
	push	eax
	mov	eax,[esp+4]				;呼び元アドレス
	sub	eax,(offset intr_Stop) - INTR_SLAVE*8	;アドレス差 + INT番号
	shr	eax,1					;eax = int番号*4

	mov	[esp+4],eax		;int番号*4 記録
	pop	eax			;eax 復元
	jmp	call_V86_HARD_int	;V86 ルーチンコール

%else	;*** CPU 割り込みと被っている ******************
	push	eax
	push	edx

	mov	edx,[esp+8]
	sub	edx,offset intr_Stop
	shr	edx,3			;edx = IRQ番号 - 8

	mov	al,0bh			;ISR 読み出しコマンド
	out	I8259A_ISR_S, al	;8259A に書き込み
	in	al, I8259A_ISR_S	;サービスレジスタ読み出し
	bt	eax,edx			;ハードウェエ割り込み？
	jnc	.CPU_int		;bit が 0 なら CPU割り込み

	lea	eax,[edx*4 + INTR_SLAVE*4]	;eax = INT番号 *4
	mov	edx,[cs:intr_table + eax*2 +4]	;edx = 呼び出しselector
	test	edx,edx				;0?
	jz	.dos_chain			;if 0 jmp

	;/// 登録してある割り込みを呼び出し ///
	mov	eax,[cs:intr_table + eax*2]	;offset

	mov	[esp+8],edx		;セレクタ
	xchg	[esp+4],eax		;eax 復元 と オフセット記録
	pop	edx
	retf				;割り込みルーチン呼び出し


	align	4
.dos_chain:
	mov	[esp+8],eax		;呼び出しINT番号として記録
	pop	edx
	pop	eax
	jmp	call_V86_HARD_int	;V86 ルーチンコール


	align	4
.CPU_int:
	lea	eax,[PM_int_00h + INTR_SLAVE*8 + edx*8]	;CPU例外 Address
	mov	[esp+8],eax

	pop	edx
	pop	eax
	ret			;CPU 例外呼び出し
%endif
%endif

;//////////////////////////////////////////////////////////////////////////////
;■割り込みサービス
;//////////////////////////////////////////////////////////////////////////////

%include	"int_dos.asm"		;DOS 割り込み処理
%include	"int_dosx.asm"		;DOS-Extender 割り込み処理
%include	"int_f386.asm"		;Free386 オリジナル API

;//////////////////////////////////////////////////////////////////////////////
;■割り込みデータ部
;//////////////////////////////////////////////////////////////////////////////

%include	"int_data.asm"		;割り込みテーブルなど

;//////////////////////////////////////////////////////////////////////////////
;//////////////////////////////////////////////////////////////////////////////
