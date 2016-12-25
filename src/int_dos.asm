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
	jmp	PM_int_21h		;チェイン

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
	jmp	PM_int_21h		;チェイン

;------------------------------------------------------------------------------
;・int 23h / CTRL-C 脱出アドレス
;------------------------------------------------------------------------------
	align	4
PM_int_23h:
	call_RegisterDumpInt	23h
	mov	ax,4c00h		;プログラム終了 (ret=00)
	jmp	PM_int_21h		;チェイン

;------------------------------------------------------------------------------
;・int 24h / 致命的エラー中断アドレス
;------------------------------------------------------------------------------
	align	4
PM_int_24h:
	call_RegisterDumpInt	24h
	mov	ax,4c00h		;プログラム終了 (ret=00)
	jmp	PM_int_21h		;チェイン

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
	jmp	PM_int_21h		;チェイン

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
	sub	esp,byte 4		;ユーザ領域（未使用）
	push	d (29h * 4)		;ベクタ番号*4 を push
	jmp	call_V86_int		;V86 割り込みルーチン呼び出し

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
	sub	esp,byte 4		;ユーザ領域（未使用）
	push	d (2fh * 4)		;ベクタ番号*4 を push
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
	align	4
PM_int_21h:
	call_RegisterDumpInt	21h

%if (int_21h_MAXF < 0ffh)
	cmp	ah,int_21h_MAXF		;テーブル最大値
	jae	int_21h_unknown		;それ以上なら jmp
%endif
	cld				;方向フラグクリア
	push	eax			;

	movzx	eax,ah				;機能番号
	mov	eax,[cs:int21h_table + eax*4]	;ジャンプテーブル参照

	;------------------------------------------
	;int 21h のみ戻り値も出力
	;------------------------------------------
%if INT_HOOK
	;
	; この時点で original eax が積まれている
	;
	cmp	b [esp + 01h], 09h	;呼び出し時 AH
	jz	short .normal_call
	cmp	d [esp + 08h], F386_cs	;呼び出し側 CS
	jz	short .normal_call

	; この時点で original eax が積まれている
	push	cs			; cs
	push	d offset .call_retern	; EIP
	pushf				; jump address
	xchg	[esp], eax		;eax=eflags, [esp]=jump address
	xchg	[esp+12], eax		;[esp+8]=eflags, eax=original eax
	ret				; テーブルジャンプ
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
	push	fs
	push	gs
	push	edx

	push	d (F386_ds)		;F386 ds
	pop	es			;es に load

	;引数のコピー
	pushad
	mov	edi,[es:int_buf_adr]	;転送先 es:edi
	mov	ecx,(INT_BUF_size /4)-1	;転送最大サイズ /4
	mov	ebp,4			;アドレス加算値
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

	mov	edx, [cs:int_buf_adr]
	calli	call_V86_int21

	pop	edx
	pop	gs
	pop	fs
	pop	es
	pop	ds
	iret_save_cy		;キャリーセーブ & iret

;------------------------------------------------------------------------------
;・文字列出力  AH=09h
;------------------------------------------------------------------------------
	align	4
int_21h_09h:
%if PRINT_TO_FILE
	jmp	int_21h_09h_output_file
%else
	push	ds
	push	es
	push	fs
	push	gs
	push	edx

	push	d (F386_ds)		;F386 ds
	pop	es			;es に load

	;引数のコピー
	pushad
	mov	edi,[es:int_buf_adr]	;転送先 es:edi
	mov	ecx,(INT_BUF_size /4)-1	;転送最大サイズ /4
	mov	ebp,4			;アドレス加算値
	mov	b [es:edi + ecx*4], '$'

	align	4
.loop:
	mov	eax,[edx]
	mov	[es:edi],eax
	cmp	al,'$'
	jz	short .exit
	cmp	ah,'$'
	jz	short .exit
	shr	eax,16			;上位→下位へ
	cmp	al,'$'
	jz	short .exit
	cmp	ah,'$'
	jz	short .exit
	add	edx,ebp		;+4
	add	edi,ebp		;+4
	loop	.loop
.exit:
	popad

	mov	edx, [cs:int_buf_adr]
	calli	call_V86_int21

	pop	edx
	pop	gs
	pop	fs
	pop	es
	pop	ds
	iret_save_cy		;キャリーセーブ & iret
%endif

;------------------------------------------------------------------------------
;【デバッグ】文字列出力を強制的にファイル出力  AH=09h
;------------------------------------------------------------------------------
%if PRINT_TO_FILE
int_21h_09h_output_file:
	; 強制ファイル出力
	pushad
	push	es
	push	ds

	mov	eax, F386_ds
	mov	ds, eax

	; file open
	push	edx
	mov	al, 01000010b
	mov	ah, 3dh
	mov	edx, .file
	calli	call_V86_int21
	pop	edx
	jc	.exit

	mov	ebx, eax	; bx = handle

	; file seek
	mov	al, 02h
	mov	ah, 42h
	xor	ecx,ecx
	xor	edx,edx
	calli	call_V86_int21

	mov	es,[esp]
	mov	esi, edx
	mov	edi, [int_buf_adr]
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
	cmp	ecx,INT_BUF_size
	jnz	short .loop
.loop_end:
	; write
	mov	ah, 40h
	calli	call_V86_int21

	; close
	mov	ah, 3eh
	calli	call_V86_int21

.exit:
	pop	ds
	pop	es
	popad
	iret

.file	db	"dump.txt",0
%endif


;------------------------------------------------------------------------------
;・バッファ付き標準1行入力  AH=0ah
;------------------------------------------------------------------------------
	align	4
int_21h_0ah:
	push	ecx
	push	edx
	push	esi
	push	edi
	push	es
	push	ds

	mov	esi,F386_ds		;DS
 	mov	 es,[esp]		;バッファアドレス
	mov	 ds,esi			;DS ロード
	mov	edi,edx			;  es:edi へ ロード

	mov	cl,[es:edi]		;最大入力バイト数
	mov	edx,[int_buf_adr]	;バッファアドレスロード
	mov	esi,edx			;esi にもバッファアドレスを
	mov	[edx],cl		;最大入力バイト数ロード

	mov	eax,[v86_cs]		;V86時 cs,ds
	push	eax			;*** call_V86 ***
	push	eax			;引数	+04h	call adress / cs:ip
	push	eax			;	+08h	V86 ds
	push	eax			;	+0ch	V86 es
	push	d [DOS_int21h_adr]	;	+10h	V86 fs
	call	call_V86		;	+14h	V86 gs
	add	esp,byte 14h		;スタック除去

	movzx	ecx,b [esi+1]		;実際に入力された文字数
	mov	[es:edi+1],cl		;呼び出し元に記録
	inc	ecx			;CR を含む文字数へ
	add	esi,byte 2		;アドレスをずらす
	add	edi,byte 2		;
	rep	movsb			;一括転送  ds:esi -> es:edi

	pop	ds
	pop	es
	pop	edi
	pop	esi
	pop	edx
	pop	ecx
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

	mov	esi,[cs:call_v86_ds]	;real ds
	shl	esi, 4			;セグメントを16倍 (para -> byte)
	add	ebx,esi			;ebx = FAT:ID ベースアドレス
	push	d (DOSMEM_Lsel)		;DOSメモリアクセスセレクタ
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
	cmp	edx,-1		;設定?
	jne	short .read	;読み出しなら jmp
	jmp	call_V86_int21

.read:	push	edx
	push	edi
	mov	edi,edx			;edi = プログラム側バッファ
	mov	edx,[cs:int_buf_adr]	;バッファアドレス
	calli	call_V86_int21		;int 21h 割り込み処理ルーチン呼び出し
	jc	short .error

	push	ecx
	push	es
	mov	ecx, F386_ds
	mov	es, ecx

	mov	cl,34			;34 byte
	align	4
.loop:	mov	ch,[es:edx]		;1 byte
	mov	[edi],ch		;   -copy
	inc	edx			;アドレス更新
	inc	edi			;
	dec	cl
	jnz	short .loop

	pop	es
	pop	ecx
	pop	edi
	pop	edx
	clear_cy
	iret

.error:	pop	edi
	pop	edx
	set_cy
	iret

;------------------------------------------------------------------------------
;・ファイルの読み込み  AH=3fh
;------------------------------------------------------------------------------
	align	4
int_21h_3fh:
	push	ecx
	push	edx
	push	esi
	push	edi
	push	ebp
	push	es
	push	ds

	mov	esi,F386_ds		;DS
 	mov	es,[esp]		;読み込み先を
	mov	ds,esi			;DS ロード

	sub	esp,byte 0ch		;*** call_V86 ***
	push	d [v86_cs]		;引数	+04h	call adress / cs:ip
	push	d [DOS_int21h_adr]	;	+08h～+14h	ds,es,fs,gs

	mov	edi,edx			;データは  es:edi へ読み込み
	mov	edx,ecx			;edx = 残り転送バイト数
	mov	ebp,ecx			;ebp = 転送バイト数

	cmp	edx,INT_BUF_size	;残りとバッファサイズを比較
	jbe	.last			;以下ならジャンプ

	align	4	;-------------------------
.loop:
	mov	ah,3fh			;File Read (dos function)

	mov	[Idata0],edx	;退避
	mov	edx,[int_buf_adr]	;読み出しバッファ
	mov	ecx,INT_BUF_size	;バッファサイズ
	call	call_V86		;ファイル読み込み  / DOS call
	mov	edx,[Idata0]	;復元
	jc	.error_exit		;Cy=1 => エラーならジャンプ

	movzx	ecx,ax			;ecx = 読み込んだバイト数
	mov	esi,[int_buf_adr]	;バッファアドレスロード
	sub	edx,ecx			;edx = 残り転送バイト数
	rep	movsb			;一括転送 ds:esi -> es:edi

	cmp	ax,INT_BUF_size		;転送サイズと実際の転送量比較
	jne	.end			;違えば転送終了（読み終えた）

	cmp	edx,INT_BUF_size	;残りとバッファサイズを比較
	ja	short .loop		;大きければ (edx > BUF_size) ループ

	align	4 ;--------------------------------
.last:
	mov	ah,3fh			;File Read (dos function)

	mov	ecx,edx			;ecx = 残りサイズ
	mov	[Idata0],edx	;退避
	mov	edx,[int_buf_adr]	;読み出しバッファ
	call	call_V86		;ファイル読み込み  / DOS call
	mov	edx,[Idata0]	;復元
	jc	.error_exit		;Cy=1 => エラーならジャンプ

	movzx	ecx,ax			;ecx = 読み込んだバイト数
	sub	edx,ecx			;edx = 残り転送バイト数
	mov	esi,[int_buf_adr]	;バッファアドレスロード
	rep	movsb			;一括転送

.end:
	mov	eax,ebp			;指定転送サイズ
	sub	eax,edx			;残り転送量を引く -> 実際の転送量

	add	esp,byte 14h		;スタック除去
 	pop	ds
	pop	es
	pop	ebp
	pop	edi
	pop	esi
	pop	edx
	pop	ecx
	clear_cy
	iret


	align	4
.error_exit:
	add	esp,byte 14h		;スタック除去
	pop	ds
	pop	es
	pop	ebp
	pop	edi
	pop	esi
	pop	edx
	pop	ecx
	set_cy
	iret


;------------------------------------------------------------------------------
;・ファイルの書き込み  AH=40h
;------------------------------------------------------------------------------
	align	4
int_21h_40h:
	push	ecx
	push	edx
	push	esi
	push	edi
	push	ebp
	push	es

	mov	edi,F386_ds		;DS
	mov	es ,edi			;  es:edi 転送先（バッファ用）
	mov	esi,edx			;  ds:esi 書き込みデータ

	sub	esp,byte 0ch		;*** call_V86 ***
	push	d [es:v86_cs]		;引数	+04h	call adress / cs:ip
	push	d [es:DOS_int21h_adr]	;	+08h～+14h	ds,es,fs,gs

	mov	edx,ecx			;edx = 残り転送バイト数
	mov	ebp,ecx			;ebp = 転送バイト数

	cmp	edx,INT_BUF_size	;残りとバッファサイズを比較
	jbe	.last			;以下ならジャンプ

	align	4	;-------------------------
.loop:
	mov	ah,40h			;File Read (dos function)

	mov	edi,[es:int_buf_adr]	;バッファアドレスロード
	mov	ecx,INT_BUF_size	;ecx = 書き込んだバイト数
	rep	movsb			;一括転送

	mov	[es:Idata0],edx	;退避
	mov	edx,[es:int_buf_adr]	;書き込みバッファ
	mov	ecx,INT_BUF_size	;バッファサイズ
	call	call_V86		;ファイル書き込み  / DOS call
	mov	edx,[es:Idata0]	;復元
	jc	.error_exit		;Cy=1 => エラーならジャンプ

	movzx	eax,ax			;eax = 書き込んだバイト数
	sub	edx,eax			;残り転送サイズから引く

	cmp	eax,INT_BUF_size	;転送サイズと実際の転送量比較
	jne	.end			;違えば転送終了（書き込み終えた）

	cmp	edx,INT_BUF_size	;残りとバッファサイズを比較
	ja	.loop			;バッファサイズより大きかったらループ

	;----------------------------------------
.last:
	mov	ah,40h			;File Read (dos function)

	mov	edi,[es:int_buf_adr]	;バッファアドレスロード
	mov	ecx,edx			;ecx = 残りサイズ
	rep	movsb			;一括転送

	mov	ecx,edx			;ecx = 残りサイズ
	mov	[es:Idata0],edx	;退避
	mov	edx,[es:int_buf_adr]	;書き込みバッファ
	call	call_V86		;ファイル書き込み  / DOS call
	mov	edx,[es:Idata0]	;復元
	jc	.error_exit		;Cy=1 => エラーならジャンプ

	movzx	ecx,ax			;ecx = 書き込んだバイト数
	sub	edx,ecx			;edx = 残り転送バイト数

.end:
	mov	eax,ebp			;指定転送サイズ
	sub	eax,edx			;残り転送量を引く -> 実際の転送量

	add	esp,byte 14h		;スタック除去
	pop	es
	pop	ebp
	pop	edi
	pop	esi
	pop	edx
	pop	ecx
	clear_cy
	iret

	align	4
.error_exit:
	add	esp,byte 14h		;スタック除去
	pop	es
	pop	ebp
	pop	edi
	pop	esi
	pop	edx
	pop	ecx
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
	align	4
int_21h_47h:
	push	edi
	push	esi
	push	ecx
	push	edx

	push	esi
	mov	esi,[cs:int_buf_adr]	;バッファアドレス
	mov	edi,esi			;edi にも

	calli	call_V86_int21		;DOS call

	pop	esi
	pushfd			;フラグ保存
	mov	ecx,64/4
.loop:
	mov	edx,[cs:edi]
	mov	[esi],edx
	add	edi,byte 4
	add	esi,byte 4
	loop	.loop

	popfd			;フラグ復元
	pop	edx
	pop	ecx
	pop	esi
	pop	edi
	iret_save_cy		;キャリーセーブ & iret

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

	mov	eax,DOSMEM_Lsel
	mov	es, eax

	mov	eax, [cs:call_v86_es]
	shl	eax, 4			;to Liner
	add	ebx, eax

	pop	eax
	iret

;------------------------------------------------------------------------------
;・ファイルの移動（リネーム）  AH=56h
;------------------------------------------------------------------------------
	align	4
int_21h_56h:
	push	edi

	push	eax
	push	ebx
	push	ecx
	push	ds

	mov	eax,F386_ds	;
	mov	ds,ax		;セグメントレジスタロード

	mov	ebx,[int_buf_adr]	;仲介バッファのアドレス
	mov	ecx,100h		;最大 100h (256) 文字
	add	ebx,ecx			;+100h の位置のバッファ
.loop:
	mov	al,[es:edi]	;es:edi 変更ファイル名
	mov	[ebx],al	;バッファへコピー
	inc	edi		;
	inc	ebx		;ポインタ更新

	test	al,al		;値check
	jz	.exit		;0 なら脱出 (0 までコピーする)
	loop	.loop
.exit:
	mov	edi,[int_buf_adr]	;仲介バッファのアドレス
	add	edi,100h		;+100h

	pop	ds
	pop	ecx
	pop	ebx
	pop	eax

	calli	int_21h_ds_edx		;DOS 呼び出し

	pop	edi
	iret_save_cy


;------------------------------------------------------------------------------
;・PSPを得る  AH=62h
;------------------------------------------------------------------------------
	align	4
int_21h_62h:
	mov	bx,PSP_sel1
	iret

