;******************************************************************************
;　Free386	割り込み処理ルーチン / DOS 仲介ルーチン
;******************************************************************************
;
; 2001/01/18 ファイルを分離
;
;
;==============================================================================
;★DOS 割り込み  int 20-2F
;==============================================================================
;------------------------------------------------------------------------------
;・int 20h / プログラムの終了
;------------------------------------------------------------------------------
proc4 PM_int_20h
	call_RegisterDumpInt	20h
	mov	ax,4c00h		;プログラム終了 (ret=00)
	jmp	PM_int_21h

;------------------------------------------------------------------------------
;・int 22h / 終了アドレス
;------------------------------------------------------------------------------
;　プログラムを終了するとき実行を移すアドレスを記録してあるベクタ。
;　現状では、int 21h / AH=4ch にチェイン
;
proc4 PM_int_22h
	call_RegisterDumpInt	22h
	mov	ax,4c00h		;プログラム終了 (ret=00)
	jmp	PM_int_21h

;------------------------------------------------------------------------------
;・int 23h / CTRL-C 脱出アドレス
;------------------------------------------------------------------------------
proc4 PM_int_23h
	call_RegisterDumpInt	23h
	mov	ax,4c00h		;プログラム終了 (ret=00)
	jmp	PM_int_21h

;------------------------------------------------------------------------------
;・int 24h / 致命的エラー中断アドレス
;------------------------------------------------------------------------------
proc4 PM_int_24h
	call_RegisterDumpInt	24h
	mov	ax,4c00h		;プログラム終了 (ret=00)
	jmp	PM_int_21h

;------------------------------------------------------------------------------
;・int 25h / 物理セクタ読み込み
;------------------------------------------------------------------------------
proc4 PM_int_25h
	call_RegisterDumpInt	25h
	iret

;------------------------------------------------------------------------------
;・int 26h / 物理セクタ書き込み
;------------------------------------------------------------------------------
proc4 PM_int_26h
	call_RegisterDumpInt	26h
	iret

;------------------------------------------------------------------------------
;・int 27h / プログラムの常駐終了
;------------------------------------------------------------------------------
proc4 PM_int_27h
	call_RegisterDumpInt	27h
	mov	ax,4c00h		;プログラム終了 (ret=00)
	jmp	PM_int_21h

;------------------------------------------------------------------------------
;・int 28h / コンソール入力時に呼ばれるアイドルルーチン
;------------------------------------------------------------------------------
proc4 PM_int_28h
	call_RegisterDumpInt	28h
	iret

;------------------------------------------------------------------------------
;・int 29h / 高速コンソール出力
;------------------------------------------------------------------------------
;	AL = 出力コード
;
proc4 PM_int_29h
	call_RegisterDumpInt	29h
	push	29h
	jmp	call_V86_int_iret

;------------------------------------------------------------------------------
;・int 2ah / MS-Networks NETBIOS
;・int 2bh / DOS reserved
;・int 2ch / DOS reserved
;・int 2dh / DOS reserved
;------------------------------------------------------------------------------
proc1 PM_int_2ah
proc1 PM_int_2bh
proc1 PM_int_2ch
proc1 PM_int_2dh
	iret

;------------------------------------------------------------------------------
;・int 2eh / shell(command.com)を実行
;------------------------------------------------------------------------------
proc4 PM_int_2eh
	call_RegisterDumpInt	2eh
	iret

;------------------------------------------------------------------------------
;・int 2fh / DOS 非公開function
;------------------------------------------------------------------------------
proc4 PM_int_2fh
	call_RegisterDumpInt	2fh
	push	2fh			; interrupt number
	jmp	call_V86_int_iret


;******************************************************************************
;・int 21h / DOS function & DOS-Extender function
;******************************************************************************
;------------------------------------------------------------------------------
;・int 21h / 非サポート
;------------------------------------------------------------------------------
proc4 int_21h_notsupp
	set_cy		;エラーに設定
	iret

;------------------------------------------------------------------------------
;・int 21h / 未知のfunction
;------------------------------------------------------------------------------
proc4 int_21h_unknown
 	jmp	call_V86_int21_iret

;==============================================================================
;・int 21h / テーブルジャンプ処理
;==============================================================================
proc4 PM_int_21h
	call_RegisterDumpInt	21h

    %if (int_21h_fn_MAX < 0ffh)
	cmp	ah,int_21h_fn_MAX		;テーブル最大値
	ja	int_21h_unknown			;それ以上なら jmp
    %endif
	push	eax
	movzx	eax,ah				;eax = AH
	mov	eax,[cs:int21h_table + eax*4]	;function table

	xchg	[esp],eax			;recovery eax
	ret					; table jump


;------------------------------------------------------------------------------
; [general purpose] DS:EDX is ASCIIZ (=NULL terminated string)
;------------------------------------------------------------------------------
proc4 int_21h_ds_edx
	push	ds
	push	es
	push	edx
	push	edi		; keep stack top

	push	F386_ds
	pop	es			;load to es

	call	get_gp_buffer_32	;
	jc	.error

	;------------------------------------------------------------
	; copy asciiz
	;------------------------------------------------------------
	push	eax
	push	ecx
	push	edi

	mov	ecx, GP_BUFFER_SIZE /4
.loop:
	mov	eax, [edx]		;copy ds:[edx]
	mov	es:[edi], eax		;  to es:[edi]
	test	al,al
	jz	.exit
	test	ah,ah
	jz	.exit
	shr	eax,16
	test	al,al
	jz	.exit
	test	ah,ah
	jz	.exit
	add	edx, 4
	add	edi, 4
	loop	.loop
.exit:
	mov	b es:[edi+3], 00h	;safety

	pop	edi
	pop	ecx
	pop	eax

	;------------------------------------------------------------
	; call V86
	;------------------------------------------------------------
	mov	edx, edi		;set edx for V86 int
	xchg	[esp], edi		;edi recovery

	V86_INT	21h

	xchg	[esp], edi		;edi = buffer pointer
	pushf
	call	free_gp_buffer_32
	popf

	pop	edi
	pop	edx
	pop	es
	pop	ds
	iret_save_cy		;キャリーセーブ & iret

.error:
	pop	edi
	pop	edx
	pop	es
	pop	ds
	clear_cy
	iret

;------------------------------------------------------------------------------
;・文字列出力  AH=09h
;------------------------------------------------------------------------------
proc4 int_21h_09h
%if PRINT_TO_FILE
	jmp	int_21h_09h_output_file
%else
	cmp	b [cs:call_buf_used], 0		; check call buffer status
	je	.skip
	iret
.skip:
	; PRINT_TSUGARU は津軽ではない環境で実行時、
	; 通常の文字列出力を行う。
	; 津軽時は jmp テーブルが書き換えられる。

	push	ds
	push	es
	push	edx

	push	F386_ds
	pop	es

	mov	b es:[call_buf_used], 1	; use call buffer

	; copy string
	pushad
	mov	edi, es:[call_buf_adr32]
	mov	ecx, es:[call_buf_size]
	shr	ecx, 2			; ecx = buffer size /4
	xor	ebx, ebx

.loop:
	mov	eax, [edx + ebx]	; copy [ds:edx]
	mov	es:[edi + ebx], eax	;   to [es:edi]
	cmp	al,'$'
	jz	short .exit
	cmp	ah,'$'
	jz	short .exit
	shr	eax,16
	cmp	al,'$'
	jz	short .exit
	cmp	ah,'$'
	jz	short .exit
	add	ebx, b 4
	loop	.loop
.exit:
	mov	b [es:edi + ecx*4 -1], '$'	; safety
	popad

	mov	edx, [es:call_buf_adr32]
	V86_INT	21h

	mov	b [es:call_buf_used], 0

	pop	edx
	pop	es
	pop	ds
	iret_save_cy		;キャリーセーブ & iret
%endif

;------------------------------------------------------------------------------
;【デバッグ】文字列出力を強制的にファイル出力  AH=09h
;------------------------------------------------------------------------------
%if PRINT_TO_FILE

proc4 int_21h_09h_output_file
	; 強制ファイル出力
	pushad
	push	es
	push	ds
	push	edx		;keep stack top

	push	F386_ds
	pop	ds

	; file open
	mov	al, 0001_0010b
	mov	ah, 3dh
	mov	edx, offset .file
	V86_INT	21h
	jc	.exit

	mov	ebx, eax	; bx = handle

	; file seek
	mov	al, 02h
	mov	ah, 42h
	xor	ecx,ecx
	xor	edx,edx
	V86_INT	21h

	; get buffer
	call	get_gp_buffer_32
	mov	ebp, edi
	jc	.exit

	mov	es,  [esp+8]	; original ds
	mov	esi, [esp]	; original edx
	;mov	edi, ebp
	xor	ecx, ecx
.loop:
	mov	al, es:[esi]
	mov	[edi], al
	cmp	al, '$'
	jz	short .loop_end
	inc	esi
	inc	edi
	inc	ecx
	cmp	ecx, GP_BUFFER_SIZE
	jb	.loop
.loop_end:
	; write
	mov	ah, 40h
	mov	edx, ebp
	V86_INT	21h

	; close
	mov	ah, 3eh
	V86_INT	21h

	; free buffer
	mov	edi, ebp
	call	free_gp_buffer_32

.exit:
	pop	edx
	pop	ds
	pop	es
	popad
	iret

.file	db	DUMP_FILE,0
%endif

;------------------------------------------------------------------------------
; [Debug] Output to Tsugaru console  AH=09h
;------------------------------------------------------------------------------
%if PRINT_TSUGARU

proc4 int_21h_09h_output_tsugaru
	pushad
	push	es
	push	ds

	push	F386_ds
	pop	ds
	mov	es, [esp]	; original ds

	; get buffer
	call	get_gp_buffer_32
	mov	ebx, edi
	jc	.exit

	mov	esi, edx
	;mov	edi, ebx
	xor	ecx, ecx
.loop:
	mov	al, es:[esi]
	mov	[edi], al
	cmp	al, '$'
	jz	short .loop_end
	inc	esi
	inc	edi
	inc	ecx
	cmp	ecx, GP_BUFFER_SIZE-1
	jb	short .loop
.loop_end:
	mov	[edi], byte 0
	cmp	w [edi-2], 0a0dh
	jne	.skip
	mov	b [edi-1], 0
.skip:
	; output for Tsugaru API
	mov	dx, 2f18h
	mov	al, 09h
	out	dx, al		; output ds:[ebx]

	; free buffer
	mov	edi, ebx
	call	free_gp_buffer_32

.exit:
	pop	ds
	pop	es
	popad
	iret

%endif

;------------------------------------------------------------------------------
;・バッファ付き標準1行入力  AH=0ah
;------------------------------------------------------------------------------
;	ds:edx	input buffer(special format)
;
proc4 int_21h_0ah
	pushad
	push	es
	push	ds
	cld

	push	F386_ds
	pop	ds

	call	get_gp_buffer_32
	mov	ebp, edi		; save gp buffer address
	jc	.exit

	mov	esi, edx		; esi <- caller buffer
	;mov	edi, ebp		; edi <- gp buffer
	movzx	ecx, b [esi]		; ecx = maximum characters
	add	ecx, b 2
	rep	movsb			; copy ds:[esi] -> es:[edi]

	push	edx
	mov	edx, ebp		; ds:edx is gp buffer
	V86_INT	21h
	pop	edx

	; edx = caller buffer
	; ebp = gp buffer
	push	ds			; exchange ds<>es
	push	es
	pop	ds			; ds = F386 ds
	pop	es			; es = caller selector

	mov	esi, ebp		; ds:[esi] gp buffer
	mov	edi, edx		; es:[edi] caller buffer
	movzx	ecx,b [esi]		; ecx = maximum characters
	add	ecx,b 2			; ecx is buffer size
	rep	movsb			; copy ds:[esi] -> es:[edi]

	mov	edi, ebp
	call	free_gp_buffer_32

.exit:
	pop	ds
	pop	es
	popad
	iret



;------------------------------------------------------------------------------
;・カレント／任意 ドライブのドライブデータ取得  AH=1bh/1ch
;------------------------------------------------------------------------------
proc4 int_21h_1bh
proc4 int_21h_1ch
	push	esi

	xor	ebx,ebx			;ebx 上位16bit クリア
	V86_INT	21h			;DS:BX = FAT-ID アドレス

	mov	esi,cs:[cv86_ds]	;real ds
	shl	esi, 4			;セグメントを16倍 (para -> byte)
	add	ebx,esi			;ebx = FAT:ID ベースアドレス
	push	DOSMEM_sel		;DOSメモリアクセスセレクタ
	pop	ds			;ds に設定

	pop	esi
	iret


;------------------------------------------------------------------------------
;・ディスク転送アドレス設定  AH=1ah
;------------------------------------------------------------------------------
proc4 int_21h_1ah
	push	es
	push	F386_ds
	pop	es

	mov	[es:DTA_off],edx	;offset
	mov	[es:DTA_seg],ds		;segment

	;*** ファンクションコールを転送機能付きに差し替え ***
	mov	d [es:int21h_table+4eh*4],offset int_21h_4eh
	mov	d [es:int21h_table+4fh*4],offset int_21h_4fh

	pop	es
	iret

;------------------------------------------------------------------------------
;・ディスク転送アドレス取得  AH=2fh
;------------------------------------------------------------------------------
proc4 int_21h_2fh
	mov	ebx, [cs:DTA_off]
	mov	es , [cs:DTA_seg]	;DTA の現在値
	iret

;------------------------------------------------------------------------------
;・常駐終了  AH=31h
;------------------------------------------------------------------------------
proc4 int_21h_31h			;未対応の機能
	jmp	int_21h_4ch

;------------------------------------------------------------------------------
;・国別情報の取得／設定  AH=38h
;------------------------------------------------------------------------------
proc4 int_21h_38h
	cmp	dx,-1
	je	call_V86_int21_iret	; setting is jmp

	;------------------------------------------------------------
	; read
	;------------------------------------------------------------
	; IN	   AL = country code
	;	   BX = country code
	;	DS:DX = buffer
	;
	pusha

	call	get_gp_buffer_32
	mov	ebp, edi		;ebp = GP buffer
	jc	.error

	mov	edi, edx		;edi = caller buffer

	mov	edx, ebp
	V86_INT	21h
	jc	.error2

	;------------------------------------------------------------
	; copy f386ds:[ebp] to ds:[edi]
	;------------------------------------------------------------
	push	ds
	push	es

	push	F386_ds
	pop	ds
	mov	es, [esp]
	;------------------------------------------------------------
	; copy ds:[ebp] to es:[edi]
	;------------------------------------------------------------
	mov	esi, ebp
	mov	ecx, 32/4	; 32byte
	rep	movsd

	pop	es
	pop	ds
	;------------------------------------------------------------
	; end of copy
	;------------------------------------------------------------

	mov	edi, ebp
	call	free_gp_buffer_32

	popa
	clear_cy
	iret

.error2:
	mov	edi, ebp
	call	free_gp_buffer_32

.error:	popa
	set_cy
	iret

;------------------------------------------------------------------------------
;・ファイルの読み込み  AH=3fh
;------------------------------------------------------------------------------
proc4 int_21h_3fh
	cmp	b [cs:call_buf_used], 0	; check call buffer status
	je	.skip
	xor	eax, eax
	set_cy
	iret
.skip:
	cld
	push	edx
	push	esi
	push	edi
	push	ebp
	push	es
	push	ds
	push	ecx	;スタック参照注意

	push	F386_ds
	pop	ds
	mov	es,[esp+4]		;読み込み先

	mov	b [call_buf_used], 1	; save call buffer flag

	mov	edi,edx			;データは  es:edi へ読み込み
	mov	edx,ecx			;edx = 残り転送バイト数
	mov	ebp,[call_buf_size]	;ebp = バッファサイズ

	cmp	edx,ebp			;残りとを比較
	jbe	.last			;以下ならジャンプ

	align	4	;-------------------------
.loop:
	xor	eax,eax
	mov	ah,3fh			;File Read (dos function)

	push	edx		;退避
	mov	edx,[call_buf_adr32]	;読み出しバッファ
	mov	ecx,ebp			;バッファサイズ
	V86_INT	21h			;ファイル読み込み  / DOS call
	pop	edx
	jc	.error_exit		;Cy=1 => エラーならジャンプ

	movzx	ecx,ax			;ecx = 読み込んだバイト数
	mov	esi,[call_buf_adr32]	;バッファアドレスロード
	sub	edx,ecx			;edx = 残り転送バイト数
	rep	movsb			;一括転送 ds:esi -> es:edi

	cmp	eax,ebp			;転送サイズと実際の転送量比較
	jne	.end			;違えば転送終了（読み終えた）

	cmp	edx,ebp			;残りとバッファサイズを比較
	ja	short .loop		;大きければ (edx > BUF_size) ループ

	align	4 ;--------------------------------
.last:
	mov	ah,3fh			;File Read (dos function)

	mov	ecx,edx			;ecx = 残りサイズ
	push	edx		;退避
	mov	edx,[call_buf_adr32]	;読み出しバッファ
	V86_INT	21h			;ファイル読み込み  / DOS call
	pop	edx		;復元
	jc	.error_exit		;Cy=1 => エラーならジャンプ

	movzx	ecx,ax			;ecx = 読み込んだバイト数
	sub	edx,ecx			;edx = 残り転送バイト数
	mov	esi,[call_buf_adr32]	;バッファアドレスロード
	rep	movsb			;一括転送

.end:
	mov	eax,[esp]		;指定転送サイズ
	sub	eax,edx			;残り転送量を引く -> 実際の転送量

	mov	b [call_buf_used], 0	; clear call buffer flag

	pop	ecx
	pop	ds
	pop	es
	pop	ebp
	pop	edi
	pop	esi
	pop	edx
	clear_cy
	iret


	align	4
.error_exit:
	mov	b [call_buf_used], 0	; clear call buffer flag

	pop	ecx
	pop	ds
	pop	es
	pop	ebp
	pop	edi
	pop	esi
	pop	edx
	set_cy
	iret


;------------------------------------------------------------------------------
;・ファイルの書き込み  AH=40h
;------------------------------------------------------------------------------
proc4 int_21h_40h
	cmp	b [cs:call_buf_used], 0	; check call buffer status
	je	.skip
	xor	eax, eax
	set_cy
	iret
.skip:
	cld
	push	edx
	push	esi
	push	edi
	push	ebp
	push	es
	push	ecx	;スタック参照注意

	push	F386_ds
	pop	es			;  es:edi 転送先（バッファ用）
	mov	esi,edx			;  ds:esi 書き込みデータ

	mov	b [es:call_buf_used], 1	; save call buffer flag

	mov	edx,ecx			;edx = 残り転送バイト数
	mov	ebp,[es:call_buf_size]	;ebp = バッファサイズ

	cmp	edx,ebp			;残りとバッファサイズを比較
	jbe	.last			;以下ならジャンプ

	align	4	;-------------------------
.loop:
	mov	ah,40h			;File Read (dos function)

	mov	edi,[es:call_buf_adr32]	;バッファアドレスロード
	mov	ecx,ebp			;ecx = 書き込んだバイト数
	rep	movsb			;一括転送

	push	edx		;退避
	mov	edx,[es:call_buf_adr32]	;書き込みバッファ
	mov	ecx,ebp			;バッファサイズ
	V86_INT	21h			;ファイル書き込み  / DOS call
	pop	edx		;復元
	jc	.error_exit		;Cy=1 => エラーならジャンプ

	movzx	eax,ax			;eax = 書き込んだバイト数
	sub	edx,eax			;残り転送サイズから引く

	cmp	eax,ebp			;転送サイズと実際の転送量比較
	jne	.end			;違えば転送終了（書き込み終えた）

	cmp	edx,ebp			;残りとバッファサイズを比較
	ja	.loop			;バッファサイズより大きかったらループ

	;----------------------------------------
.last:
	mov	ah,40h			;File Read (dos function)

	mov	edi,[es:call_buf_adr32]	;バッファアドレスロード
	mov	ecx,edx			;ecx = 残りサイズ
	rep	movsb			;一括転送

	mov	ecx,edx			;ecx = 残りサイズ
	push	edx		;退避
	mov	edx,[es:call_buf_adr32]	;書き込みバッファ
	V86_INT	21h			;ファイル書き込み  / DOS call
	pop	edx		;復元
	jc	.error_exit		;Cy=1 => エラーならジャンプ

	movzx	ecx,ax			;ecx = 書き込んだバイト数
	sub	edx,ecx			;edx = 残り転送バイト数

.end:
	mov	eax,[esp]		;指定転送サイズ
	sub	eax,edx			;残り転送量を引く -> 実際の転送量

	mov	b [es:call_buf_used], 0	; clear call buffer flag

	pop	ecx
	pop	es
	pop	ebp
	pop	edi
	pop	esi
	pop	edx
	clear_cy
	iret

	align	4
.error_exit:
	mov	b [es:call_buf_used], 0	; clear call buffer flag

	pop	ecx
	pop	es
	pop	ebp
	pop	edi
	pop	esi
	pop	edx
	set_cy
	iret


;------------------------------------------------------------------------------
;・IOCTRL  AH=44h
;------------------------------------------------------------------------------
proc4 int_21h_44h
	jmp	call_V86_int21_iret
	;
	; not support AL=02h-05h
	;


;------------------------------------------------------------------------------
;・カレントディレクトリの取得  AH=47h
;------------------------------------------------------------------------------
; in	ds:esi	64 byte buffer
;	    dl	drive number
;
proc4 int_21h_47h
	push	ecx
	push	edx
	push	edi
	push	esi

	call	get_gp_buffer_32	;edi = buffer
	mov	esi, edi
	jc	.error

	V86_INT	21h			;save to ds:si
	jc	.error_free_gp

	mov	esi, [esp]		;copy cs:edi to ds:esi
	xor	ecx, ecx
.loop:
	mov	edx, cs:[edi+ecx]
	mov	[esi+ecx], edx
	add	cl, 4
	cmp	cl, 64
	jb	.loop

	; edi = buffer
	call	free_gp_buffer_32

	pop	esi
	pop	edi
	pop	edx
	pop	ecx
	clear_cy
	iret

.error_free_gp:
	; edi = buffer
	call	free_gp_buffer_32

.error:
	pop	esi
	pop	edi
	pop	edx
	pop	ecx
	set_cy
	iret


;------------------------------------------------------------------------------
;・最初に一致するファイルの検索  AH=4eh
;------------------------------------------------------------------------------
proc4 int_21h_4eh
	callint	int_21h_ds_edx	;DOS call

.copy_dta:
	pushfd			;FLAGS save
	push	ds
	push	es
	push	esi
	push	edi
	push	ecx
	cld

	push	F386_ds
	pop	ds

	mov	esi,80h		;PSP ds:[80h]
	mov	es ,[DTA_seg]
	mov	edi,[DTA_off]
	mov	ecx,28h /4	;DTA size 2Bh
	rep	movsd		;copy 28h byte

	mov	cl, 3
	rep	movsb		;copy 3 byte

	pop	ecx
	pop	edi
	pop	esi
	pop	es
	pop	ds

	popfd
	iret_save_cy		;Carry save & return


;------------------------------------------------------------------------------
;・次に一致するファイルの検索  AH=4fh
;------------------------------------------------------------------------------
proc4 int_21h_4fh
	V86_INT	21h
	jmp	int_21h_4eh.copy_dta


;------------------------------------------------------------------------------
;【汎用】ES:BXでのみ、戻り値が返る。 AH=34h(InDOS flag), AH=52h(MCB/Undoc)
;------------------------------------------------------------------------------
proc4 int_21h_ret_esbx
	xor	ebx, ebx
	V86_INT	21h		;int 21h 割り込み処理ルーチン呼び出し

	push	eax

	mov	eax,DOSMEM_sel
	mov	 es,ax

	mov	eax, cs:[cv86_es]
	shl	eax, 4			;to Liner
	add	ebx, eax

	pop	eax
	iret

;------------------------------------------------------------------------------
;・ファイルの移動（リネーム）  AH=56h
;------------------------------------------------------------------------------
; IN	ds:edx	move from
;	es:edi	move to
; Ret	Cy
;
proc4 int_21h_56h
	push	edi

	push	eax
	push	ebx
	push	ecx
	push	ds

	push	F386_ds
	pop	ds

	push	edi
	call	get_gp_buffer_32
	mov	ebx, edi		;ebx = buffer
	pop	edi
	jc	.error

	xor	ecx, ecx
.loop:
	mov	al, es:[edi+ecx]	; copy from [es:edi]
	mov	[ebx+ecx], al		; copy to   [ds:ebx]
	test	al,al
	jz	.skip

	inc	ecx
	cmp	ecx, GP_BUFFER_SIZE
	jb	.loop

	mov	b [ebx + GP_BUFFER_SIZE-1], 0	;safety

.skip:
	mov	edi, ebx		; buffer address

	pop	ds
	pop	ecx
	pop	ebx
	pop	eax
	callint	int_21h_ds_edx		;call DOS

	pushf	;edi = buffer
	call	free_gp_buffer_32
	popf

	pop	edi
	iret_save_cy

.error:
	pop	ds
	pop	ecx
	pop	ebx
	pop	eax
	pop	edi
	set_cy
	iret


;------------------------------------------------------------------------------
;・PSPを得る  AH=62h
;------------------------------------------------------------------------------
proc4 int_21h_62h
	mov	bx,PSP_sel1
	iret

