;******************************************************************************
;　Free386	割り込み処理ルーチン / DOS 仲介ルーチン
;******************************************************************************
;
; 2001/01/18 ファイルを分離
;
;
BITS	32
;==============================================================================
;★DOS 割り込み  int 20-2F
;==============================================================================
;------------------------------------------------------------------------------
;・int 20h / プログラムの終了
;------------------------------------------------------------------------------
	align	4
PM_int_20h:
	call_RegisterDumpInt	20h
	mov	ax,4c00h		;プログラム終了 (ret=00)
	jmp	PM_int_21h

;------------------------------------------------------------------------------
;・int 22h / 終了アドレス
;------------------------------------------------------------------------------
;　プログラムを終了するとき実行を移すアドレスを記録してあるベクタ。
;　現状では、int 21h / AH=4ch にチェイン
;
	align	4
PM_int_22h:
	call_RegisterDumpInt	22h
	mov	ax,4c00h		;プログラム終了 (ret=00)
	jmp	PM_int_21h

;------------------------------------------------------------------------------
;・int 23h / CTRL-C 脱出アドレス
;------------------------------------------------------------------------------
	align	4
PM_int_23h:
	call_RegisterDumpInt	23h
	mov	ax,4c00h		;プログラム終了 (ret=00)
	jmp	PM_int_21h

;------------------------------------------------------------------------------
;・int 24h / 致命的エラー中断アドレス
;------------------------------------------------------------------------------
	align	4
PM_int_24h:
	call_RegisterDumpInt	24h
	mov	ax,4c00h		;プログラム終了 (ret=00)
	jmp	PM_int_21h

;------------------------------------------------------------------------------
;・int 25h / 物理セクタ読み込み
;------------------------------------------------------------------------------
	align	4
PM_int_25h:
	call_RegisterDumpInt	25h
	iret

;------------------------------------------------------------------------------
;・int 26h / 物理セクタ書き込み
;------------------------------------------------------------------------------
	align	4
PM_int_26h:
	call_RegisterDumpInt	26h
	iret

;------------------------------------------------------------------------------
;・int 27h / プログラムの常駐終了
;------------------------------------------------------------------------------
	align	4
PM_int_27h:
	call_RegisterDumpInt	27h
	mov	ax,4c00h		;プログラム終了 (ret=00)
	jmp	PM_int_21h

;------------------------------------------------------------------------------
;・int 28h / コンソール入力時に呼ばれるアイドルルーチン
;------------------------------------------------------------------------------
	align	4
PM_int_28h:
	call_RegisterDumpInt	28h
	iret

;------------------------------------------------------------------------------
;・int 29h / 高速コンソール出力
;------------------------------------------------------------------------------
;	AL = 出力コード
	align	4
PM_int_29h:
	call_RegisterDumpInt	29h
	push	d 29h			; ベクタ番号
	jmp	call_V86_int		; V86 割り込みルーチン呼び出し

;------------------------------------------------------------------------------
;・int 2ah / MS-Networks NETBIOS
;・int 2bh / DOS reserved
;・int 2ch / DOS reserved
;・int 2dh / DOS reserved
;------------------------------------------------------------------------------
	align	4
PM_int_2ah:
PM_int_2bh:
PM_int_2ch:
PM_int_2dh:
	iret

;------------------------------------------------------------------------------
;・int 2eh / shell(command.com)を実行
;------------------------------------------------------------------------------
	align	4
PM_int_2eh:
	call_RegisterDumpInt	2eh
	iret

;------------------------------------------------------------------------------
;・int 2fh / DOS 非公開function
;------------------------------------------------------------------------------
	align	4
PM_int_2fh:
	call_RegisterDumpInt	2fh
	push	d 2fh			;ベクタ番号
	jmp	call_V86_int		;V86 割り込みルーチン呼び出し


;******************************************************************************
;・int 21h / DOS function & DOS-Extender function
;******************************************************************************
;------------------------------------------------------------------------------
;・int 21h / 非サポート
;------------------------------------------------------------------------------
	align	4
int_21h_notsupp:
	set_cy		;エラーに設定
	iret

;------------------------------------------------------------------------------
;・int 21h / 未知のfunction
;------------------------------------------------------------------------------
	align	4
int_21h_unknown:
 	jmp	call_V86_int21

;==============================================================================
;・int 21h / テーブルジャンプ処理
;==============================================================================
proc PM_int_21h
	call_RegisterDumpInt	21h

    %if (int_21h_MAXF < 0ffh)
	cmp	ah,int_21h_MAXF		;テーブル最大値
	ja	int_21h_unknown		;それ以上なら jmp
    %endif
	cld				;方向フラグクリア
	push	eax			;

	movzx	eax,ah				;機能番号
	mov	eax,[cs:int21h_table + eax*4]	;ジャンプテーブル参照

	;------------------------------------------
	;int 21h のみ戻り値も出力
	;------------------------------------------
	%if INT_HOOK && INT_HOOK_RETV
		push	cs			; cs
		push	d offset .call_retern	; EIP
		pushf				; jump address
		xchg	[esp], eax		;eax=eflags, [esp]=jump address
		xchg	[esp+12], eax		;[esp+8]=eflags, eax=original eax
		ret				; テーブルジャンプ
	align 4
	.call_retern:
		;save_cy
		jc	.set_cy
		clear_cy
		jmp	short .saved
	.set_cy:
		set_cy
	.saved:
		call_RegisterDumpInt	-2
		iret
	%endif

.normal_call:
	;------------------------------------------
	;通常呼び出し
	;------------------------------------------
	xchg	[esp],eax	;eax復元 & ジャンプ先記録
	ret			; table jump


;------------------------------------------------------------------------------
;【汎用】DS:EDXに NULL で終わる文字列
;------------------------------------------------------------------------------
	align	4
int_21h_ds_edx:
	push	ds
	push	es
	push	edx

	push	d (F386_ds)		;F386 ds
	pop	es			;es に load

	push	eax

	call	get_gp_buffer_32
	test	eax, eax
	jz	.error

	;------------------------------------------------------------
	;引数のコピー
	;------------------------------------------------------------
	pushad
	mov	edi, eax
	mov	ecx,(GP_BUFFER_SIZE /4)-1	;転送最大サイズ /4
	mov	ebp,4				;アドレス加算値
	mov	b [es:edi + ecx*4], 00h

	align	4
.loop:
	mov	eax,[edx]
	mov	[es:edi],eax
	test	al,al
	jz	short .exit
	test	ah,ah
	jz	short .exit
	shr	eax,16			;上位→下位へ
	test	al,al
	jz	short .exit
	test	ah,ah
	jz	short .exit
	add	edx,ebp		;+4
	add	edi,ebp		;+4
	loop	.loop
.exit:
	popad

	mov	edx, eax	; edx <- GP buffer address
	xchg	[esp], eax	; recovery eax
	calli	call_V86_int21

	xchg	[esp], eax	; eax <- GP buffer address
	call	free_gp_buffer_32
	pop	eax

	pop	edx
	pop	es
	pop	ds
	iret_save_cy		;キャリーセーブ & iret

.error:
	pop	eax
	pop	edx
	pop	es
	pop	ds
	clear_cy
	iret

;------------------------------------------------------------------------------
;・文字列出力  AH=09h
;------------------------------------------------------------------------------
	align	4
int_21h_09h:
%if PRINT_TO_FILE
	jmp	int_21h_09h_output_file
%else
	cmp	d [cs:call_buf_used], 0		; check call buffer status
	je	.skip
	iret
.skip:
	; PRINT_TSUGARU は津軽ではない環境で実行時、
	; 通常の文字列出力を行う。
	; 津軽時は jmp テーブルが書き換えられる。

	push	ds
	push	es
	push	edx

	push	d (F386_ds)
	pop	es

	mov	d [es:call_buf_used], 1	; use call buffer

	; copy string
	pushad
	mov	edi,[es:call_buf_adr32]
	mov	ecx,[es:call_buf_size]
	shr	ecx, 2			; ecx = buffer size /4
	xor	ebx, ebx

	align	4
.loop:
	mov	eax, [edx + ebx]	; copy [ds:edx]
	mov	[es:edi + ebx], eax	;   to [es:edi]
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
	calli	call_V86_int21

	mov	d [es:call_buf_used], 0

	pop	edx
	pop	es
	pop	ds
	iret_save_cy		;キャリーセーブ & iret
%endif

;------------------------------------------------------------------------------
;【デバッグ】文字列出力を強制的にファイル出力  AH=09h
;------------------------------------------------------------------------------
%if PRINT_TO_FILE

proc int_21h_09h_output_file
	; 強制ファイル出力
	pushad
	push	ds
	push	es

	mov	eax, F386_ds
	mov	ds, eax

	; file open
	push	edx
	mov	al, 0001_0010b
	mov	ah, 3dh
	mov	edx, offset .file
	calli	call_V86_int21
	pop	edx
	jc	.exit

	mov	ebx, eax	; bx = handle

	; file seek
	push	edx
	mov	al, 02h
	mov	ah, 42h
	xor	ecx,ecx
	xor	edx,edx
	calli	call_V86_int21
	pop	edx

	; get buffer
	call	get_gp_buffer_32
	mov	ebp, eax
	test	eax, eax
	jz	.exit

	mov	es,[esp+4]	; original ds
	mov	esi, edx
	mov	edi, ebp
	mov	edx, edi
	xor	ecx, ecx
.loop:
	mov	al, [es:esi]
	mov	[edi], al
	cmp	al, '$'
	jz	short .loop_end
	inc	esi
	inc	edi
	inc	ecx
	cmp	ecx, GP_BUFFER_SIZE
	jnz	short .loop
.loop_end:
	; write
	mov	ah, 40h
	calli	call_V86_int21

	; close
	mov	ah, 3eh
	calli	call_V86_int21

	; free buffer
	mov	eax, ebp
	call	free_gp_buffer_32

.exit:
	pop	es
	pop	ds
	popad
	iret

.file	db	DUMP_FILE,0
%endif

;------------------------------------------------------------------------------
; [Debug] Output to Tsugaru console  AH=09h
;------------------------------------------------------------------------------
%if PRINT_TSUGARU

proc int_21h_09h_output_tsugaru
	pushad
	push	ds
	push	es

	mov	eax, F386_ds
	mov	ds, eax
	mov	es,[esp+4]	; original ds

	; get buffer
	call	get_gp_buffer_32
	mov	ebx, eax
	test	eax, eax
	jz	.exit

	mov	esi, edx
	mov	edi, ebx
	xor	ecx, ecx
.loop:
	mov	al, [es:esi]
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
	mov	b [edi-1], 0

	; output for Tsugaru API
	mov	dx, 2f18h
	mov	al, 09h
	out	dx, al

	; free buffer
	mov	eax, ebx
	call	free_gp_buffer_32

.exit:
	pop	es
	pop	ds
	popad
	iret

%endif

;------------------------------------------------------------------------------
;・バッファ付き標準1行入力  AH=0ah
;------------------------------------------------------------------------------
;	ds:edx	input buffer(special format)
;
	align	4
int_21h_0ah:
	pushad
	push	es
	push	ds

	mov	esi,F386_ds
	mov	 es,esi

	push	eax
	call	get_gp_buffer_32
	mov	ebp, eax		; save gp buffer address
	test	eax, eax
	pop	eax
	jz	.exit

	mov	esi, edx		; esi <- caller buffer
	mov	edi, ebp		; edi <- gp buffer
	movzx	ecx, b [edi]		; ecx = maximum characters
	add	ecx, b 2
	rep	movsb			; copy [ds:esi] -> [es:edi]

	push	edx
	mov	edx, ebp		; ds:edx is gp buffer
	calli	call_V86_int21
	pop	edx

	; edx = caller buffer
	; ebp = gp buffer
	push	ds			; exchange ds<>es
	mov	eax,  es
	mov	 ds, eax		; ds = F386 ds
	pop	es			; es = caller selector

	mov	esi, ebp		; [ds:esi] gp buffer
	mov	edi, edx		; [es:edi] caller buffer
	movzx	ecx,b [esi]		; ecx = maximum characters
	add	ecx,b 2			; ecx is buffer size
	rep	movsb			; copy [ds:esi] -> [es:edi]

	mov	eax, ebp
	call	free_gp_buffer_32

.exit:
	pop	ds
	pop	es
	popad
	iret



;------------------------------------------------------------------------------
;・カレント／任意 ドライブのドライブデータ取得  AH=1bh/1ch
;------------------------------------------------------------------------------
	align	4
int_21h_1bh:
int_21h_1ch:
	push	esi

	xor	ebx,ebx			;ebx 上位16bit クリア
	calli	call_V86_int21		;DS:BX = FAT-ID アドレス

	mov	esi,[cs:call_V86_ds]	;real ds
	shl	esi, 4			;セグメントを16倍 (para -> byte)
	add	ebx,esi			;ebx = FAT:ID ベースアドレス
	push	d (DOSMEM_sel)		;DOSメモリアクセスセレクタ
	pop	ds			;ds に設定

	pop	esi
	iret


;------------------------------------------------------------------------------
;・ディスク転送アドレス設定  AH=1ah
;------------------------------------------------------------------------------
	align	4
int_21h_1ah:
	push	es
	push	d (F386_ds)
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
	align	4
int_21h_2fh:
	mov	ebx, [cs:DTA_off]
	mov	es , [cs:DTA_seg]	;DTA の現在値
	iret

;------------------------------------------------------------------------------
;・常駐終了  AH=31h
;------------------------------------------------------------------------------
	align	4
int_21h_31h:			;未対応の機能
	jmp	int_21h_4ch

;------------------------------------------------------------------------------
;・国別情報の取得／設定  AH=38h
;------------------------------------------------------------------------------
	align	4
int_21h_38h:
	cmp	dx,-1
	je	near call_V86_int21	; 設定なら jmp

	;------------------------------------------------------------
	; read 
	;------------------------------------------------------------
	push	edx
	push	edi
	push	esi

	push	eax
	call	get_gp_buffer_32
	mov	esi, eax		;esi = GP buffer
	pop	eax

	test	esi, esi
	jz	short .error

	mov	edi, edx		;edi = プログラム側バッファ
	mov	edx, esi		;バッファアドレス
	calli	call_V86_int21		;int 21h 割り込み処理ルーチン呼び出し
	jc	short .error2

	;------------------------------------------------------------
	; copy es:[edx] to ds:[edi]
	;------------------------------------------------------------
	push	ecx
	push	es
	mov	ecx, F386_ds
	mov	 es, ecx

	mov	cl, 32			;32 byte
	align	4
.loop:	mov	ch,[es:edx]		;1 byte
	mov	[edi],ch		;  copy
	inc	edx			;
	inc	edi			;
	dec	cl
	jnz	short .loop

	pop	es
	pop	ecx

	mov	eax, esi
	call	free_gp_buffer_32

	pop	esi
	pop	edi
	pop	edx
	clear_cy
	iret

.error2:
	mov	eax, esi
	call	free_gp_buffer_32

.error:	pop	esi
	pop	edi
	pop	edx
	set_cy
	iret

;------------------------------------------------------------------------------
;・ファイルの読み込み  AH=3fh
;------------------------------------------------------------------------------
	align	4
int_21h_3fh:
	cmp	d [cs:call_buf_used], 0	; check call buffer status
	je	.skip
	xor	eax, eax
	set_cy
	iret
.skip:

	push	edx
	push	esi
	push	edi
	push	ebp
	push	es
	push	ds
	push	ecx	;スタック参照注意

	mov	esi,F386_ds		;DS
	mov	ds,esi			;DS ロード
 	mov	es,[esp+4]		;読み込み先

	mov	d [call_buf_used], 1	; save call buffer flag

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
	calli	call_V86_int21		;ファイル読み込み  / DOS call
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
	calli	call_V86_int21		;ファイル読み込み  / DOS call
	pop	edx		;復元
	jc	.error_exit		;Cy=1 => エラーならジャンプ

	movzx	ecx,ax			;ecx = 読み込んだバイト数
	sub	edx,ecx			;edx = 残り転送バイト数
	mov	esi,[call_buf_adr32]	;バッファアドレスロード
	rep	movsb			;一括転送

.end:
	mov	eax,[esp]		;指定転送サイズ
	sub	eax,edx			;残り転送量を引く -> 実際の転送量

	mov	d [call_buf_used], 0	; clear call buffer flag

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
	mov	d [call_buf_used], 0	; clear call buffer flag

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
	align	4
int_21h_40h:
	cmp	d [cs:call_buf_used], 0	; check call buffer status
	je	.skip
	xor	eax, eax
	set_cy
	iret
.skip:
	push	edx
	push	esi
	push	edi
	push	ebp
	push	es
	push	ecx	;スタック参照注意

	mov	edi,F386_ds		;DS
	mov	es ,edi			;  es:edi 転送先（バッファ用）
	mov	esi,edx			;  ds:esi 書き込みデータ

	mov	d [es:call_buf_used], 1	; save call buffer flag

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
	calli	call_V86_int21		;ファイル書き込み  / DOS call
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
	calli	call_V86_int21		;ファイル書き込み  / DOS call
	pop	edx		;復元
	jc	.error_exit		;Cy=1 => エラーならジャンプ

	movzx	ecx,ax			;ecx = 書き込んだバイト数
	sub	edx,ecx			;edx = 残り転送バイト数

.end:
	mov	eax,[esp]		;指定転送サイズ
	sub	eax,edx			;残り転送量を引く -> 実際の転送量

	mov	d [es:call_buf_used], 0	; clear call buffer flag

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
	mov	d [es:call_buf_used], 0	; clear call buffer flag

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
	align	4
int_21h_44h:			;未対応の機能
	nop	;「うんづ」との相性問題？　メモリ破壊？
	jmp	call_V86_int21
	;
	;誤魔化し
	;
	;これでは AL=02h-05h に対応できない
	;
	iret


;------------------------------------------------------------------------------
;・カレントディレクトリの取得  AH=47h
;------------------------------------------------------------------------------
; in	ds:esi	64 byte buffer
;	    dl	drive number
;
proc int_21h_47h
	push	ecx
	push	edx
	push	edi
	push	esi

	push	eax
	call	get_gp_buffer_32
	mov	esi, eax
	mov	edi, eax
	pop	eax
	test	esi, esi
	jz	.error

	calli	call_V86_int21	;save to ds:si
	jc	.error_free_gp

	mov	esi, [esp]	;copy cs:edi to ds:esi
	xor	ecx, ecx
.loop:
	mov	edx,[cs:edi+ecx]
	mov	[esi+ecx],edx
	add	cl, 4
	cmp	cl, 64
	jb	.loop

	push	eax
	mov	eax, edi
	call	free_gp_buffer_32
	pop	eax

	pop	esi
	pop	edi
	pop	edx
	pop	ecx
	clear_cy
	iret

.error_free_gp:
	push	eax
	mov	eax, edi
	call	free_gp_buffer_32
	pop	eax

.error:
	pop	esi
	pop	edi
	pop	edx
	pop	ecx
	set_cy
	iret

;------------------------------------------------------------------------------
;・子プログラムの実行  AH=4bh
;------------------------------------------------------------------------------
	align	4
int_21h_4bh:
	set_cy
	iret


;------------------------------------------------------------------------------
;・最初に一致するファイルの検索  AH=4eh
;------------------------------------------------------------------------------
	align	4
int_21h_4eh:
	calli	int_21h_ds_edx		;DOS call

	pushfd			;FLAGS save
	push	ds
	push	es
	push	esi
	push	edi
	push	ecx

	mov	esi,F386_ds
	mov	ecx,28h /4	;データ領域サイズ /4
	mov	ds ,si		;DS を F386 のモノに
	mov	es ,[DTA_seg]
	mov	esi,80h
	mov	edi,[DTA_off]
	rep	movsd		;一括データ転送

	mov	cl,3		;残り 3byte 転送
	rep	movsb		;バイト転送

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
	align	4
int_21h_4fh:
	calli	call_V86_int21		;DOS call

	pushfd			;FLAGS save
	push	ds
	push	es
	push	esi
	push	edi
	push	ecx

	mov	esi,F386_ds
	mov	ecx,28h /4	;データ領域サイズ /4
	mov	ds ,si		;DS を F386 のモノに
	mov	es ,[DTA_seg]
	mov	esi,80h
	mov	edi,[DTA_off]
	rep	movsd		;一括データ転送

	mov	cl,3		;残り 3byte 転送
	rep	movsb		;バイト転送

	pop	ecx
	pop	edi
	pop	esi
	pop	es
	pop	ds

	popfd
	iret_save_cy		;Carry save & return


;------------------------------------------------------------------------------
;【汎用】ES:BXでのみ、戻り値が返る。 AH=34h(InDOS flag), AH=52h(MCB/Undoc)
;------------------------------------------------------------------------------
	align	4
int_21h_ret_esbx:
	xor	ebx, ebx
	calli	call_V86_int21		;int 21h 割り込み処理ルーチン呼び出し

	push	eax

	mov	eax,DOSMEM_sel
	mov	es, eax

	mov	eax, [cs:call_V86_es]
	shl	eax, 4			;to Liner
	add	ebx, eax

	pop	eax
	iret

;------------------------------------------------------------------------------
;・ファイルの移動（リネーム）  AH=56h
;------------------------------------------------------------------------------
;	ds:edx	move from
;	es:edi	move to
;
	align	4
int_21h_56h:
	push	edi

	push	eax
	push	ebx
	push	ecx
	push	ds

	mov	eax,F386_ds
	mov	 ds,eax

	call	get_gp_buffer_32
	test	eax, eax
	jz	short .error

	mov	ebx, eax
	xor	ecx, ecx
.loop:
	mov	al,[es:edi+ecx]		; copy from [es:edi]
	mov	[ebx+ecx],al		; copy to   [ds:ebx]
	test	al,al
	jz	.skip

	inc	ecx
	cmp	ecx, GP_BUFFER_SIZE
	jb	.loop
	mov	b [ebx], 0		; force fail

.skip:
	mov	edi, ebx		; buffer address

	pop	ds
	pop	ecx
	pop	ebx
	pop	eax
	calli	int_21h_ds_edx		;call DOS

	pushf
	push	eax
	mov	eax, edi
	call	free_gp_buffer_32
	pop	eax
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
	align	4
int_21h_62h:
	mov	bx,PSP_sel1
	iret

