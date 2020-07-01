;******************************************************************************
;　Free386 macro
;******************************************************************************
;
;
%imacro	PRINT86	1
	mov	dx,%1
	mov	ah,09h
	int	21h
%endmacro

%imacro	PRINT	1
	mov	edx,%1
	mov	ah,09h
	int	21h
%endmacro

%imacro	PRINT_	1
	push	eax
	push	edx
	mov	edx,%1
	mov	ah,09h
	int	21h
	pop	edx
	pop	eax
%endmacro

%imacro	PRINT_crlf	0
	mov	ah,02h
	mov	dl,13
	int	21h
	mov	dl,10
	int	21h
%endmacro

%imacro	Program_end	1	;***** プロセス終了 *****
	mov	ah,4ch
	mov	al,%1
	int	21h	;終了
%endmacro

%imacro getvecter	0	;ベクタアドレス取得 > ES:BX
	mov	ah,35h
	mov	al,Interrupt_No	;定義済 Int 番号
	int	21h
%endmacro

%imacro	setvecter	0	;ベクタアドレス設定 < DS:DX
	mov	ah,25h
	mov	al,Interrupt_No	;定義済 Int 番号
	int	21h
%endmacro

;******************************************************************************
;★F386 専用マクロ
;******************************************************************************
;------------------------------------------------------------------------------
;・XMS Driver を call するマクロ
;------------------------------------------------------------------------------
%macro	XMS_function	0
	call	far [XMS_entry]		;XMS far call
%endmacro


;------------------------------------------------------------------------------
;・F386 のプロテクトモードを終了させる
;------------------------------------------------------------------------------
%macro	F386_end	1
	mov	b [f386err],%1		;エラー番号記録
	jmp	END_program
%endmacro

;------------------------------------------------------------------------------
;・V86 の int を発効するマクロ
;------------------------------------------------------------------------------
%macro	V86_INT	1
	pushf
	push	cs
	push	d (offset .ret_label)
	push	d %1*4			;int番号 *4
	jmp	call_V86_int

	align	4
.ret_label:
%endmacro

%macro	V86_INT_21h	0
	pushf
	push	cs
	call	call_V86_int21
%endmacro

;------------------------------------------------------------------------------
;・V86 からの割り込みを判別するマクロ（未使用 / VCPI利用時は不要）
;------------------------------------------------------------------------------
;%macro	check_int_from_V86	0
;	test	b [esp+10],02h		;+08h にある EFLAGS の VMビット
;	jnz	near int_from_V86	;V86モードからの割り込み専用ルーチンへ
;%endmacro

;------------------------------------------------------------------------------
;・キャリークリア & キャリーセット
;------------------------------------------------------------------------------
%imacro	set_cy	0	;Carry set
	or	b [esp+8], 01h	;Carry セット
%endmacro

%imacro	clear_cy 0	;Carry reset
	and	b [esp+8],0feh	;Carry クリア
%endmacro

save_cy:	;
cy_save:	;誤植防止措置
cy_set:		;
cy_clear:	;

;------------------------------------------------------------------------------
;・キャリーの状態をセーブして iret するマクロ
;------------------------------------------------------------------------------
%imacro	iret_save_cy	0	;Cy をセーブし iretd する
	jc	.__set_cy
	clear_cy
	iret
.__set_cy:
	set_cy
	iret
%endmacro

;------------------------------------------------------------------------------
;・INT 呼び出しのようにラベルを call するマクロ
;------------------------------------------------------------------------------
%imacro	calli	1	;Cy をセーブし iretd する
	pushf
	push	cs
	call	%1
%endmacro

;------------------------------------------------------------------------------
;・レジスタダンプ
;------------------------------------------------------------------------------
%imacro call_RegisterDump_with_code	1
	mov	d [dump_err_code], %1
	call	register_dump		;safe
%endmacro
;------------------------------------------------------------------------------
;・INT用レジスタダンプ
;------------------------------------------------------------------------------
%imacro call_RegisterDumpInt	1
%if INT_HOOK
	push	d %1
	call	register_dump_from_int	;safe
	mov	[esp], eax
	pop	eax
%endif
%endmacro

;******************************************************************************
;ディバグ用マクロ
;******************************************************************************

%imacro	SPEED_N		0	;ディバグ用 > 互換モード切替え
	push	dx
	push	ax
	mov	dx,5ech
	xor	al,al
	out	dx,al
	pop	ax
	pop	dx
%endmacro

%imacro	PAD_WAIT	0	;ディバグ用 > 互換モード切替え
	push	eax
	push	edx
	push	ebp

	mov	dx,4d0h
._off	in	al,dx
	test	al,10h
	jz	._off

._on	in	al,dx
	dec	ebp
	test	al,10h
	jnz	._on

	pop	ebp
	pop	edx
	pop	eax
%endmacro


%macro	FAULT	0	;ディバグ用 / メモリ保護エラー
	mov	[offset -1],eax
%endmacro


