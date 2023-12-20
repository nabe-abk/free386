;******************************************************************************
; subroutine for Free386
;******************************************************************************
;[TAB=8]
;
;------------------------------------------------------------------------------

%include "macro.inc"
%include "f386def.inc"

%include "start.inc"
%include "sub.inc"
%include "free386.inc"
%include "memory.inc"
%include "selector.inc"

;------------------------------------------------------------------------------
global	dump_err_code
global	dump_orig_esp
global	dump_orig_ss
;------------------------------------------------------------------------------

segment	text32 class=CODE align=4 use32
;##############################################################################
;stack dump
;	This is PDS.
;	original made by 合著@ABK  2000/07/24
;##############################################################################
;------------------------------------------------------------------------------
;●レジスタダンプ表示
;------------------------------------------------------------------------------
;;	mov		eax, 0dh		; 例外番号
;;	mov		ebx, offset dmy_tbl	; 渡されるテーブル
;;
%imacro	to_hex	1
	mov	edx,offset %1
	call	eax2hex
%endmacro

%if INT_HOOK
;------------------------------------------------
proc32 register_dump_from_int
;------------------------------------------------
	push	ds
	push	eax
	;
	; call元アドレスをexception number代わりに使う
	; comの仕様上, 100h より小さいことは無い
	;
	;stack
	;	+18h	eflags
	;	+14h	cs
	;	+10h	eip
	;	+0ch	int number
	;	+08h	caller (or exception number)
	;	+04h	ds
	;	+00h	eax
	;
	push	d F386_ds
	pop	ds
	;
	; target AH
	;
	%if INT_HOOK_AH
		cmp	ah, INT_HOOK_AH
		jne	short .no_dump
	%endif
	;
	; target CS
	;
	%if INT_HOOK_CS
		cmp	d [esp+14h], INT_HOOK_CS
		jne	short .no_dump
	%endif
	;
	; exclude CS
	;
	%if INT_HOOK_EX_CS
		cmp	d [esp+14h], INT_HOOK_EX_CS
		je	short .no_dump
	%endif
	;
	; Free386 internal call ignore
	;
	%if !INT_HOOK_F386
		cmp	d [esp+14h], F386_cs
		je	short .no_dump
	%endif
	;
	; int 21h, ah=09h は必ず無視
	;
	cmp	b [esp+0ch], 21h
	jnz	short .skip
	cmp	ah, 09h
	jz	short .no_dump
.skip:

	push	d [esp+18h]	; eflags
	popf			; recovery

	mov	eax, [blue_int_str]
	mov	[regdump_msg], eax	;"Int = "

	call	register_dump_fault

	mov	eax, [blue_err_str]
	mov	[regdump_msg], eax	;"Err = "

	%if INT_HOOK_RETV
		cmp	b [esp+1],  4ch	; ah!=4ch
		jne	.skip2
		cmp	b [esp+0ch],21h	; int 21h
		je	.no_dump
	.skip2:
		cmp	b [.in_dump], 0
		jnz	.no_dump
		mov	b [.in_dump], 1

		mov	eax, [esp+10h]
		mov	[.orig_eip], eax
		mov	eax, [esp+14h]
		mov	[.orig_cs],  eax
		mov	d [esp+10h], offset .int_retern
		mov	  [esp+14h], cs
	%endif

.no_dump:
	push	d [esp+18h]	; eflags
	popf			; recovery

	pop	eax
	pop	ds
	ret

%if INT_HOOK_RETV
	align 4
.int_retern:
	pushf
	push	d [cs:.orig_cs]
	push	d [cs:.orig_eip]
	push	d -2			; for return value dump
	push	d 100h			; dummy
	push	ds
	push	eax

	push	d F386_ds
	pop	ds
	mov	b [.in_dump], 0

	call	register_dump_fault

	pop	eax
	pop	ds
	add	esp, 8
	iret

	align	4
.in_dump	dd	0
.orig_eip	dd	0
.orig_cs	dd	0
%endif
%endif

;------------------------------------------------
proc32 register_dump
;------------------------------------------------
	pushf
	push	cs
	push	eax	; EIP dummy
	push	d [cs:dump_err_code]
	push	d 100h	; Exception number
	push	ds
	push	eax
	mov	eax, F386_ds
	mov	  ds,ax
	mov	eax,[esp+1ch]	; caller
	mov	[esp+10h],eax
	mov	d [dump_err_code], -1

	call	register_dump_fault

	pop	eax
	pop	ds
	add	esp, 10h
	popf
	ret

	;stack
	;	+1ch	eflags
	;	+18h	cs
	;	+14h	eip
	;	+10h	error code
	;	+0ch	exception number
	;	+08h	ds
	;	+04h	eax
	align 4
;------------------------------------------------
;------------------------------------------------
proc32 register_dump_fault
	; in	stack +04h	eax
	;
	; レジスタ保存, ds設定済で呼び出すこと
	;
	cld
	push	edx
	push	ecx
	push	ebx
	push	eax

	mov	eax, [esp+14h]
	to_hex	blue_eax
	mov	eax, [esp+04h]
	to_hex	blue_ebx
	mov	eax, [esp+08h]
	to_hex	blue_ecx
	mov	eax, [esp+0ch]
	to_hex	blue_edx

	mov	eax, esi
	to_hex	blue_esi
	mov	eax, edi
	to_hex	blue_edi
	mov	eax, ebp
	to_hex	blue_ebp

	mov	eax, [esp+20h]
	to_hex	blue_errorcode
	mov	eax, [esp+24h]
	to_hex	blue_eip
	mov	eax, [esp+28h]
	to_hex	blue_cs

	mov	eax, [esp+18h]
	to_hex	blue_ds
	mov	eax, es
	to_hex	blue_es
	mov	eax, fs
	to_hex	blue_fs
	mov	eax, gs
	to_hex	blue_gs

	mov	eax, [dump_orig_ss]
	mov	d [dump_orig_ss], -1
	cmp	eax, -1
	jz	short .current_ss

	to_hex	blue_ss
	mov	eax,[dump_orig_esp]
	to_hex	blue_esp
	jmp	short .end_ss
.current_ss:
	mov	eax, esp
	add	eax, b 30h
	to_hex	blue_esp
	mov	eax, ss
	to_hex	blue_ss
.end_ss:

	mov	eax, cr0
	to_hex	blue_cr0
	mov	eax, cr2
	to_hex	blue_cr2
	mov	eax, cr3
	to_hex	blue_cr3

	mov	eax, [esp + 2ch]	; eflags
	mov	edx, offset blue_flags +1

	test	ah, 004h	; OF
	setnz	bl
	or	bl, '0'
	mov	[edx],bl

	test	ah, 002h	; DF
	setnz	bl
	or	bl, '0'
	mov	[edx + 3*1],bl

	test	al, 040h	; Zero
	setnz	bl
	or	bl, '0'
	mov	[edx + 3*2],bl

	test	al, 020h	; Zero
	setnz	bl
	or	bl, '0'
	mov	[edx + 3*3],bl

	test	al, 001h	; Carry
	setnz	bl
	or	bl, '0'
	mov	[edx + 3*4],bl

	to_hex	blue_eflags

	;CPU例外による呼び出し？
	mov	ebx, offset regdump_msg
	mov	eax, [esp + 1ch]
	cmp	eax, 0ffh
	ja	.no_exception

	mov	dl, [err_max]
	cmp	al, dl
	jbe	.exp1
	mov	al, dl
.exp1:
	movzx	ecx, b [err_size]
	mul	ecx	; edx broken
	lea	ebx, [err_00 + eax]
	mov	edx, offset blue_intno
.loop:
	mov	al, [ebx]
	mov	[edx], al
	inc	ebx
	inc	edx
	loop	.loop
	mov	ebx, offset blue_screen
	jmp	short .print

.no_exception:
	cmp	d [esp+20h], -2
	jne	.print
	PRINT	string_return
	PRINT	offset regdump_ds
	PRINT	string_crlf
	jmp	short .exit

.print:
	PRINT	ebx
.exit:
	pop	eax
	pop	ebx
	pop	ecx
	pop	edx
	ret

;================================================
;convert to hex
;================================================
; EAX を [EDX] へ１６進数文字列として格納
	align 4
eax2hex:
	mov	bl,[edx+4]
	cmp	bl,'_'
	jz	.loop
	shl	eax, 16
.loop:
	mov	ebx, eax
	shr	ebx, 28
	mov	 cl, [hex_str + ebx]
	mov	[edx], cl
	inc	edx
	shl	eax, 4

	mov	bl, [edx]
	cmp	bl, ' '
	jz	.end
	cmp	bl, ':'
	jz	.end
	cmp	bl, 'h'
	jz	.end
	cmp	bl, 13
	jz	.end

	cmp	bl, '_'
	jnz	.loop
	inc	edx
	jmp	short .loop
.end:
	ret

;##############################################################################
; search PATH/ENV
;##############################################################################
;/////////////////////////////////////////////////////////////////////////////
; get ENV pointer by ENV name
;/////////////////////////////////////////////////////////////////////////////
; in	[ebx]	env name
;
; ret	cy=0	fs:[edx] target env value
;	cy=1	fs:[edx] env end after "00h 00h" or zero
;
proc32 search_env
	push	eax
	push	ebx
	push	ecx
	push	esi
	push	ebp

	mov	eax, DOSENV_sel
	mov	 fs, ax
	lsl	ebp, eax		; ebp = env selector limit

	xor	esi, esi
	jmp	short .compare		; find start

.next_env:
	add	esi, ecx
.next_env_loop:
	cmp	byte fs:[esi-1], 0
	je	.compare
	inc	esi
	dec	ebp
	jz	.not_found
	jmp	short .next_env_loop

.compare:
	xor	ecx, ecx		; need before "found_env_end"
	cmp	byte fs:[esi], 0	; ENV first byte is 0
	je	.found_env_end		; 
.compare_loop:
	mov	al, fs:[esi + ecx]	; ENV memory
	mov	dl,    [ebx + ecx]	; ENV name
	inc	ecx
	dec	ebp
	jz	.not_found

	test	al, al			; found 0 in ENV
	jz	.next_env

	test	dl, dl			; dl==0
	jnz	.skip
	cmp	al, '='
	je	.match
.skip:
	cmp	al, dl
	jne	.next_env
	jmp	.compare_loop


.match:
	mov	edx, esi
	add	edx, ecx	; edx = found address
	clc			; success
.ret:
	pop	ebp
	pop	esi
	pop	ecx
	pop	ebx
	pop	eax
	ret

.not_found:
	xor	edx, edx
	stc
	jmp	short .ret

.found_env_end:
	mov	edx, esi
	inc	edx
	stc
	jmp	short .ret



;/////////////////////////////////////////////////////////////////////////////
; search PATH, find file from PATH
;/////////////////////////////////////////////////////////////////////////////
; in	[esi]	find file name
;	[ebx]	env name
;	 edi	work address (size:100h)
;
; ret	fs	destroy
;	cy=0	found: store [edi] found file name
;	cy=1	not found
;
proc32 search_path
	pusha

	call	search_env	; fs:[edx] = ENV string
	jc	.fail
	cmp	byte fs:[edx],'0'
	je	.fail

	mov	ebp, edi	; ebp = save edi
.copy_path_start:
	mov	ecx, 0ffh -1	; ebp = file name limit, -1 for '\' mark

.copy_path:
	mov	al, fs:[edx]
	mov	[edi], al
	inc	edx
	inc	edi

	test	al, al
	jz	.copy_fname
	cmp	al, ';'
	je	.copy_fname

	loop	.copy_path
	jmp	short .fail	; buffer over flow

.copy_fname:			; copy file name
	mov	byte [edi-1], '\'

	xor	ebx, ebx
.copy_fname_loop:
	mov	al, [esi + ebx]
	mov	[edi + ebx], al
	test	al, al
	jz	.copy_finish

	inc	ebx
	loop	.copy_fname_loop
	jmp	short .fail	; buffer over flow

.copy_finish:
	;
	; edx = PATH + "\" + filename
	;
%if 0
	push	edx			; print path name for test
	mov	edx, ebp
	call	print_string_32
	pop	edx
%endif

	mov	edi, ebp
	call	check_readable_file
	jnc	.success

	cmp	byte fs:[edx-1], 0
	jne	.copy_path_start

.fail:
	stc
	popa
	ret

.success:
	;clc
	popa	; success
	ret


;/////////////////////////////////////////////////////////////////////////////
; check readable file
;/////////////////////////////////////////////////////////////////////////////
; in	[edi]	file name
; ret	cy=0	success
;	cy=1	fail
;
proc32 check_readable_file
	push	eax
	push	ebx
	push	edx

	mov	ah, 3dh		; file open
	mov	al, 100_000b	; 100=share, 000=read mode
	mov	edx, edi
	int	21h
	jc	.ret

	mov	ebx, eax	; ebx = file handle
	mov	ah, 3eh		; file close
	int	21h

	clc
.ret:
	pop	edx
	pop	ebx
	pop	eax
	ret

;##############################################################################
; load EXP file
;##############################################################################

;	IN	[edx]	ファイル名 (ASCIIz)
;		[esi]	バッファアドレス(min 200h)
;
;	Ret	Carry = 0 / ロード成功
;		fs	ロードプログラム cs
;		gs	ロードプログラム ds
;		edx	ロードプログラム EIP
;		ebp	ロードプログラム ESP
;
;		Carry = 1 / ロード失敗
;		ah	エラーコード (F386内部エラーコードと同一)
;
;------------------------------------------------------------------------------
;●EXP ファイルのロード
;------------------------------------------------------------------------------
proc32 load_exp
	push	ds			;最後に積むこと
	mov	es,[esp]		;es に設定

	;/// ファイルオープン ///
	;mov	edx,[ファイル名]	;ファイル名 ASCIIz
	mov	ax,3d00h		;file open(read only)
	int	21h			;dos call
	jc	NEAR .file_open_error	;Cy=1 ならオープンエラー

	mov	ebx,eax			;bx <- file handl番号
	mov	[file_handle],eax	;同じくメモリにも記録

	;
	;ヘッダ部ロード
	;
	mov	edx,esi			;ワークアドレス
	mov	ecx,200h		;読み込むバイト数
	mov	ah,3fh			;file read ->ds:edx
	int	21h			;dos call
	jc	NEAR .file_read_error	;Cy=1 ならリードエラー

	;
	;ヘッダ部解析
	;
	mov	eax,[esi]
	cmp	eax,00013350H		;P3 形式['P3']・フラットモデル[w (0001)]
	jne	NEAR .load_MZ_exp	;P3 でなければ MZヘッダか確認 (jmp)

	;
	;必要なメモリ算出
	;
	mov	ecx,[esi+74h]	;ロードイメージの大きさ（プログラムのサイズ）

	mov	eax,ecx
	add	eax,[esi+56h]	;ファイルの後ろに割り当てるメモリの最小量
	add	eax,     0fffh	;4KB 単位でメモリを扱うので端数繰り上げ
	and	eax,0fffff000h	;4KB 単位へ
	mov	[5ch],eax	;PSP に記録 /最低限必要なメモリサイズ[byte]

	add	ecx,[esi+5ah]	;ファイルの後ろに割り当てるメモリの最大量
	jnc	.step		;値オーバーしてなければ jmp
	mov	ecx,0fffff000h	;最大値
.step:	add	ecx,     0fffh	;4KB 単位でメモリを扱うので端数繰り上げ
	shr	ecx,12		;4KB 単位へ

	push	esi
	mov	esi,[esi+5eh]		;ベースメモリアドレス
	call	make_cs_ds		;cs/ds 作成とメモリ確保
	pop	esi
	jc	NEAR .not_enough_memory	;エラーならメモリ不足

	;
	;メモリ量チェック
	;
	mov	ebx,[60h]		;実際に割り当てたメモリ [byte]
	mov	eax,[5ch]		;PSP に記録 / 最低限必要なメモリ [byte]
	cmp	ebx,eax			;値比較
	jb	NEAR .not_enough_memory	;負数ならメモリ不足

	sub	ebx,[esi+74h]		;ロードイメージの大きさを引く
	mov	[64h],ebx		;ヒープメモリ総量を PSPに記録

	;
	;ロードプログラムのスタックと実行開始アドレスを記録
	;
	mov	eax,[esi + 62h]	;スタックポインタ
	mov	ebx,[esi + 68h]	;実行開始アドレス
	mov	[data3],eax	;esp
	mov	[data4],ebx	;eip

	;
	;★★★プログラムロード★★★
	;
	mov	ebx,[file_handle]	;ebx <- ファイルハンドル番号ロード
	mov	 dx,[esi + 26h]		;プログラムまでのファイル内オフセット
	mov	 cx,[esi + 28h]		; bit 31-16
	mov	ax,4200h		;ファイル先頭からポインタ移動
	int	21h			;dos call（file pointer = cx:dx）
	jc	.file_read_error	;Cy=1 なら エラー

	mov	ecx,[esi + 2ah]		;読む込むサイズ（プログラムサイズ）
	mov	edx,[esi + 5eh]		;読み込む先頭メモリ(ds:edx)
					;+5eh には"ベースアドレス"がある
	mov	 ds,[Load_ds]		;ロード先セレクタ値ロード

	;
	;-PACK でリンク時に PACK されているかチェック
	;
	mov	eax,[es:esi+72h]	;ヘッダの フラグ初期値
	test	al,01h			;bit 0 を check

	push  d offset .sl_un_pack_ret	;call の戻りラベル
	jnz	NEAR exp_un_pack_fread	;PACK を解きながらファイル読み込み
	add	esp,byte (4)		;スタック除去(戻りラベル)


.file_read:		;MZ ヘッダロードから呼ばれる
	;
	;ファイルリード
	; ds:edx に ecx バイト読み込む
	;
	mov	ah,3fh			;file read
	int	21h			;DOS コール
	jc	.file_read_error	;キャリーが 1 なら リードエラー


	align	4
.sl_un_pack_ret:
	mov	ah,3eh			;ファイルクローズ
	int	21h			;dos コール

	pop	ds
	mov	ebp,[data3]		;esp
	mov	edx,[data4]		;eip
	mov	 fs,[Load_cs]		;cs
	mov	 gs,[Load_ds]		;ds
	clc				;キリャークリア
	ret

.file_read_error:
	mov	ds, [esp]		;スタックトップから DS 復元
	mov	ebx,[file_handle]	;ebx <- ファイルハンドル番号ロード
	mov	ah,3eh			;ファイルクローズ
	int	21h			;dos call
.file_open_error:
	mov	ah,22			;'File read error'
	pop	ds
	stc				;キリャーセット
	ret

.not_enough_memory:
	mov	cl,23			;'Memory is insufficient'
.fclose_end:
	pop	ds

	mov	ebx,[file_handle]	;ebx <- ファイルハンドル番号ロード
	mov	ah,3eh			;ファイルクローズ
	int	21h			;dos call

	mov	ah,cl			;ah = エラーコード
	stc				;キリャーセット
	ret

.ftype_error:
	mov	cl,24			;'Unknown EXP header'
	jmp	short .fclose_end	;ファイルをクローズしてから終了



;----------------------------------------------------------------------
;○MZ ヘッダを持つ EXP ファイルのロード
;----------------------------------------------------------------------
;	mov	eax,[esi]
;	cmp	eax,00013350H	;P3 形式['P3']・フラットモデル[w (0001)]
;	jne	NEAR check_MZ	;P3 でなければ MZヘッダか確認 (jmp)
;
proc32 .load_MZ_exp

	;////////////////////////////////////////////////////
	;MZ(MP) ヘッダに対応しない場合
	;////////////////////////////////////////////////////
%if (USE_MZ_EXP = 0)
	jmp	short .ftype_error	;MZ ヘッダに対応しない
%else

	;////////////////////////////////////////////////////
	;MZ(MP) ヘッダロードルーチン
	;////////////////////////////////////////////////////
	cmp	ax,'MP'			;MZ(MP) ヘッダ?
	jne	.ftype_error		;違ったら 未対応形式

	;
	;必要なメモリ算出
	;
	;+02h   file size & 511
	;+04h  (file size + 511) >> 9   // Thanks to Mamiya (san)
	;
	mov	ebp,eax		;ebp = eax
	shr	ebp,16		;+02 w "ファイルサイズ / 512" の余り
	movzx	eax,w [esi+04h]	;+04 w "512 byte 単位のブロック数"
	movzx	edx,w [esi+08h]	;+08 w "ヘッダ  サイズ / 16"

	test	ebp,ebp		;ebp = 0 ?
	jz	.step2		;0 なら jmp
	dec	eax		;端数あり?
.step2:
	shl	eax,9		;512倍
	shl	edx,4 		; 16倍

	; *** edx, ebp を下の方まで保存すること

	or	eax, ebp	;eax = (512 byteブロック数)*512 + 511以下の端数
	sub	eax, edx	;eax = ヘッダサイズを引く
	mov	ebp, eax	;edi = load image size
	add	eax, 000000fffh	;
	and	eax, 0fffff000h	;eax = load image size (4KB unit)

	movzx	ebx,w [esi+0ah]	;+0A w "ヒープの最小量 / 4KB"
	movzx	ecx,w [esi+0ch]	;+0C w "ヒープの最大要求量 / 4KB"
	shl	ebx,12
	shl	ecx,12
	add	ebx, eax	; minimum memory pages
	add	ecx, eax	; maximum memory pages
	mov	[5ch], ebx

	push	esi			; ecx = pages
	xor	esi,esi			; esi = base offset address
	call	make_cs_ds		;cs/ds 作成とメモリ確保
	pop	esi
	jc	.not_enough_memory	;エラーならメモリ不足

	;
	;メモリ量チェック
	;
	mov	eax, [60h]		;実際に割り当てたメモリ [byte]
	cmp	eax, ebx		;値比較
	jb	.not_enough_memory	;負数ならメモリ不足

	sub	eax, ebp		;ロードイメージの大きさを引く
	mov	[64h], eax		;PSPに記録 / ヒープメモリ総量 [byte]

	;
	;スタックを exp のものに変更
	;
	mov	eax,[esi + 0eh]	;スタックポインタ
	mov	ebx,[esi + 14h]	;実行開始アドレス
	mov	[data3],eax	;esp
	mov	[data4],ebx	;eip

	;
	;以下、P3 のコピー
	;
	mov	ebx,[file_handle]	;ebx <- ファイルハンドル番号ロード
	xor	ecx,ecx			;ecx = 0
	;mov	edx,---		;代入済	;edx = プログラムイメージまでの offset
	mov	ax,4200h		;ファイル先頭からポインタ移動
	int	21h			;DOS call（file pointer = cx:dx）
	jc	NEAR .file_read_error	;Cy=1 なら エラー

	mov	ecx, ebp		;読む込むサイズ（プログラムサイズ）
	xor	edx, edx		;読み込む先頭メモリ(ds:edx)

	mov	edi,[Load_ds]		;ロード先セレクタ値ロード
	mov	 ds,edi			;

	jmp	.file_read		;実際の読み込み処理 (P3 Header と共通)
%endif


;======================================================================
;○EXP の PACK を溶きながらファイルをリードするサブルチーン (P3ヘッダ)
;======================================================================
;
;	special thanks to PEN@海猫 氏（資料提供）
;
;	in	   ebx = ファイルハンドラ番号
;		ds:edx = ファイルを読み込むメモリ位置
;		   ecx = ファイルを読み込むサイズ
;
;		es:esi = ワークメモリ(200h byte)
;
	align	4
exp_un_pack_fread:
	push	ebp
	push	edi

	mov	ebp,ecx		;ebp = 読み込むバイト数

	;
	;セグメントレジスタ ds･es の交換
	;
	mov	eax,es
	mov	ecx,ds
	mov	  ds,ax
	mov	  es,cx
	mov	[data1],eax	;このプログラム
	mov	[data2],ecx	;読み込み先

	;
	;↑により ds がこのセグメントを示すようになった
	;
	mov	edi,edx			;edi <- ファイル読み込み先
	mov	edx,esi			;edx <- ワークメモリ
	mov	[data0],esi		;汎用変数に一時的に記憶


	align	4
exp_up_loop:	;*** ループスタート ****************************
	;
	;ds:edx = ワークメモリ
	;es:edi = ファイルロード領域
	;   ebx = ファイルハンドラ番号
	;   ebp = 残り読み込みバイト数

	test	ebp,ebp			;残り byte 数
	jz	exp_up_fread_eof	;if 0 jmp 処理終了

	;
	; 2 byte リード
	;
	mov	ecx,2			;2 byte
	sub	ebp,ecx			;ebp = 残りサイズ
	mov	ah,3fh			;file read
	int	21h			;DOS コール
	jc	short exp_up_fread_err	;キャリーがあればリードエラー
	test	ax,ax			;ax を確認
	jz	short exp_up_fread_eof	;0 なら EOF である

	xor	eax,eax			;eax の上位16bit クリア
	mov	 ax,[edx]		;eax <- 読み込んだデータ
	bt	eax,15			;ビット 15 を確認
	jc	short pack_length	;1 ならパックされている

	;
	;パックされていない$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
	;
	mov	edx,edi			;edx <- プログラムロード領域
	mov	ecx,eax			;ecx = 読み込むバイト数
	sub	ebp,eax			;ebp = 残りサイズ
	add	edi,eax			;リードバイト数だけプログラムロード領域
					; のアドレスをステップする

	mov	 ds, [data2]		;ds = ファイルロード領域

	;
	;ds:edx = プログラムロード領域
	;
	mov	ah,3fh			;file read
	int	21h			;DOS コール
	jc	short exp_up_fread_err	;キャリーがあればリードエラー

	mov	 ds, [cs:data1]		;このプログラムの ds
	mov	edx, [data0]		;ワークエリアオフセットを戻す
	;
	;↑ds:edx をワーク領域に復元
	;

	jmp	exp_up_loop		;ループさせる***********



	;
	;/// ルーチン終了 //////////////////////////////////////
	;
	align	4
exp_up_fread_eof:	;ファイルを最後まで読んで、処理しきった
	;
	;セグメントレジスタ ds･es を元に戻す
	;
	mov	 es,[data1]	;このプログラム
	mov	 ds,[data2]	;ロード領域

	pop	edi
	pop	ebp
	ret

	;
	;/// ファイル読み込み時のエラー ////////////////////////
	;
	align	4
exp_up_fread_err:
	pop	edi
	pop	ebp
	add	esp,4				;戻りラベル除去
	jmp	load_exp.file_read_error	;エラーによる脱出
	;///////////////////////////////////////////////////////



	align	4
	;
	;PACK されている $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
	;
pack_length:
	and	eax,7fffh	;ビット15 を 0 にする
	mov	esi,eax		;esi に値記憶

	dec	ebp			;ebp = 残りバイト数
	mov	ecx,1			;1 byte
	mov	ah,3fh			;file read
	int	21h			;DOS コール
	jc	short exp_up_fread_err	;キャリーがあればリードエラー

	xor	eax,eax			;eax クリア
	mov	al,[edx]		;読み込んだ値を確認
	test	al,al			;＝and al,al
	jnz	short str_length	;0 でなければ文字列の繰り返し圧縮

	;
	;NULL コードのレングス圧縮である
	;
	mov	ecx,esi			;指定バイト数分
	rep	stosb			;NULL を展開する ->es:edi

	jmp	exp_up_loop		;ループさせる***********



	align	4
	;
	;文字列で PACK されている $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
	;
str_length:
	mov	cl,al			;ecx <- 繰り返す文字列の長さ
	sub	ebp,eax			;ebp = 残りバイト数
	mov	ah,3fh			;file read
	int	21h			;DOS コール
	jc	short exp_up_fread_err	;キャリーがあればリードエラー

	push	ebx			;ebx 保存
	xor	ebx,ebx			;ebx クリア

	mov	ah,cl			;ah <- 文字列の長さ
	mov	ecx,esi			;コピーバイト数

	align	4
str_length_loop:
	mov	al,[edx + ebx]		;文字列ロード
	inc	bl			;文字列内オフセ	ットステップ
	cmp	bl,ah			;文字長と比較
	je	short strl_lp_offsetc	; 0 ならオフセットクリア

	mov	[es:edi],al		;1 byte 書き込み
	inc	edi			;アドレス更新
	loop	str_length_loop		;ecx をカウンタに 0 になるまでループ

	pop	ebx
	jmp	exp_up_loop		;ループさせる***********

	align	4
strl_lp_offsetc:	;ebx の 0 にループさせる
	xor	bl,bl			;ebx = 0

	mov	[es:edi],al		;1 byte 書き込み
	inc	edi			;アドレス更新
	loop	str_length_loop		;ecx をカウンタに 0 になるまでループ

	pop	ebx
	jmp	exp_up_loop		;ループさせる***********


;======================================================================
;○プログラムをロードするセレクタを作成するサブルチーン
;======================================================================
;引数	ecx	要求最大量(page)
;	esi	読み込み先をずらす量(P3ヘッダ -offset オプション)
;
;Ret	Cy=0 成功
;		実際の割り当て量(byte)を PSP の [60h] に記録
;		Load_cs, Load_ds にロード用セレクタの cs/ds 記録
;	Cy=1 失敗
;
	align	4
	global	make_cs_ds
make_cs_ds:
	push	eax
	push	ebx
	push	ecx
	push	edx
	push	esi
	push	ebp

	mov	ebp,[free_RAM_pages]	;空きメモリと比較
	add	ebp,[DOS_mem_pages]	;DOSメモリ

	mov	[60h],esi		;save base offset
	mov	edx,esi			;読み込みベース
	shr	edx,12			;page単位のずれ / 下まで破壊しないこと

	mov	eax,ecx			;割り当て要求量
	add	eax,edx			;eax = 必要アドレス量
	add	eax,3ffh		;端数切捨て
	shr	eax,10			;eax = ページテーブル用に必要なメモリ
	add	eax,ecx			;要求量のメモリを作成するに必要なメモリ
	cmp	eax,ebp ;=free_pages	;空きメモリと比較
	jbe	.do_alloc		;足りればメモリ割り当てへjmp

.alloc_all:	;全空きメモリ割り当て
	mov	ecx,ebp ;=free_pages	;空きメモリをロード
	movzx	eax,b [pool_for_paging]	;プールメモリ数
	sub	ecx,eax			;予約メモリページ数を引く
	ja	.mem_pool		;0 以上なら jmp
	add	ecx,eax			;値を元に戻す(プールしない)
.mem_pool:
	mov	eax,ecx			;全空きページ数
	add	eax,edx			;アドレスずれ分のアドレス量
	add	eax,3ffh		;端数切上げ
	shr	eax,10			;eax = ページテーブル用に必要なメモリ
	sub	ecx,eax			;空きページ数から引く
	jb	near .no_memory		;マイナスならエラー
.do_alloc:
	mov	ebp, [free_liner_adr]	;貼り付け先アドレスを保存
	push	esi
	and	esi, 0xfffff000		;ずらし量
	add	esi, ebp		;空きリニアアドレスに加算
	mov	[free_liner_adr], esi	;ずらす
	pop	esi

	push	ecx
	call	alloc_DOS_mem		;DOSメモリを先頭に割り当て
	pop	ecx
	jc	.no_memory		;エラーjmp

	push	ecx
	sub	ecx, eax		;割り当て済ページ数を引く
	call	alloc_RAM		;メモリ割り当て
	pop	ecx		; ecxはまだ使う
	jc	.no_memory		;エラーjmp

	;セレクタ作成
	call	search_free_LDTsel	;eax = 空きセレクタ
	jc	.no_selector		;if エラー jmp
	mov	[Load_cs],eax		;セレクタ値記録

	mov	edi,[work_adr]		;edi ワークアドレス
	add	ecx,edx			;オフセットのずれを加算
	dec	ecx			;page数 -1
	mov	[edi  ],ebp		;ベース
	mov	[edi+4],ecx		;limit
	mov	d [edi+8],0a00h		;R/X タイプ / 特権レベル=0

	mov	esi, [60h]		;load base offset
	inc	ecx			;ecx = サイズ (page)

	shl	ecx, 12			;ecx = サイズ (byte)
	sub	ecx, esi		;ベースオフセットを引く
	mov	[60h],ecx		;PSP 領域に記録
	call	make_selector_4k	;メモリセレクタ作成 edi=構造体 eax=sel

	;ds 作成
	call	search_free_LDTsel	;eax = 空きセレクタ
	jc	.no_selector		;if エラー jmp
	mov	[Load_ds],eax		;セレクタ値記録

	mov	ebx,[Load_cs]		;コピー元
	mov	ecx,eax			;コピー先
	mov	 ax,0200h		;R/W タイプ / 特権レベル=0
	call	make_alias		;エイリアス作成

	clc				;正常終了
.exit:
	pop	ebp
	pop	esi
	pop	edx
	pop	ecx
	pop	ebx
	pop	eax
	ret

.no_memory:
.no_selector:
	stc
	jmp	.exit


;=============================================================================
;●ロードしたプログラムを実行するサブルーチン
;=============================================================================
;	IN	fs	ロードプログラム cs
;		gs	ロードプログラム ds
;		edx	ロードプログラム EIP
;		ebp	ロードプログラム ESP
;
proc32 run_exp
	mov	eax,gs			;DS
	mov	 ss,ax			;
	mov	esp,ebp			;スタック切り替え

	push	fs			;cs
	push	edx			;EIP

	mov	ds,ax			;
	mov	es,ax			;セレクタ初期設定
	mov	fs,ax			;
	mov	gs,ax			;

	;
	;全ての汎用レジスタクリア（起動時の初期値）
	;
	xor	eax,eax
	xor	ebx,ebx
	xor	ecx,ecx
	xor	edx,edx
	xor	edi,edi
	xor	esi,esi
	xor	ebp,ebp

	;
	;★★★目的プログラムの実行★★★
	;
	retf		;far return

;******************************************************************************
; DATA
;******************************************************************************
segment	data class=DATA align=4
;------------------------------------------------------------------------------
;・レジスタダンプ表示
;------------------------------------------------------------------------------
; db "Expection Interrupted : INT 00h -                                 ",13,10
; db "ErrorCode = ####_####  CS:EIP = ####:####_####  EFLAGS = ####_####",13,10
; db "DS = ####  ES = ####  SS = ####  FS = ####  GS = ####             ",13,10
; db "CR0 = ####_####  CR1 = ****_****  CR2 = ####_####  CR3 = ####_####",13,10
; db "EAX = ####_####  EBX = ####_####  ECX = ####_####  EDX = ####_####",13,10
; db "ESI = ####_####  EDI = ####_####  EBP = ####_####  ESP = ####_####",13,10
; db "$"

blue_screen:	;;	db 01Bh,"[46m"
		db "----------------------------------------"
		db "--------------------------",13,10
		db "Expection Interrupted : INT "
blue_intno	db "##h -                                 ",13,10,
regdump_msg	db "Err = " ;blue_err_strで書き換えるので変更時は注意
blue_errorcode	db "####_####  "
blue_cseip	db "CS:EIP = "
blue_cs		db "####:"
blue_eip	db "####_####   SS:ESP = "
blue_ss		db "####:"
blue_esp	db "####_####",13,10,
regdump_ds	db " DS = "
blue_ds		db "####        ES = "
blue_es		db "####        FS = "
blue_fs		db "####        GS = "
blue_gs		db "####",13,10,"EAX = "
blue_eax	db "####_####  EBX = "
blue_ebx	db "####_####  ECX = "
blue_ecx	db "####_####  EDX = "
blue_edx	db "####_####",13,10,"ESI = "
blue_esi	db "####_####  EDI = "
blue_edi	db "####_####  EBP = "
blue_ebp	db "####_####  FLG = "
blue_eflags	db "####_####",13,10,"CR0 = "
blue_cr0	db "####_####  CR2 = "
;blue_cr1 / CPU に存在しない
blue_cr2	db "####_####  CR3 = "
blue_cr3	db "####_####  "
blue_flags	db "O  D  S  Z  C  ",13,10
		db "----------------------------------------"
		db "--------------------------",13,10
;;		db 0x1b,"[40;0m"
		db "$"
string_return	db 'Return:'
string_crlf	db 13,10,'$'

blue_err_str	db	"Err "
blue_int_str	db	"Int "

extern	hex_str		;Definded in sub.asm
;hex_str 	db	'0123456789ABCDEF'

err_size	db	34
err_max		db	12h
			;1234567890123456789012345678901234
err_00		db	'00h - Zero Divide Error           '
err_01		db	'01h - Debug Exceptions            '
err_02		db	'02h - NMI                         '
err_03		db	'03h - Breakpoint                  '
err_04		db	'04h - INTO Overflow Fault         '
err_05		db	'05h - Bounds Check Fault          '
err_06		db	'06h - Invalid Opcode Fault        '
err_07		db	'07h - Coprocessor Not Available   '
err_08		db	'08h - Double Fault                '
err_09		db	'09h - Coprocessor Segment Overrun '
err_0a		db	'0Ah - Invalid TSS                 '
err_0b		db	'0Bh - Segment Not Present Fault   '
err_0c		db	'0Ch - Stack Exception Fault       '
err_0d		db	'0Dh - General Protection Exception'
err_0e		db	'0Eh - Page Fault                  '
err_0f		db	'0Fh - (CPU RESERVED)              '
err_10		db	'10h - Coprocessor Error           '
err_11		db	'11h - Alignment Fault             '
err_dmy		db	'1xh - Unknown (Stack broken?)     '

	align	4
dump_err_code	dd	-1
dump_orig_esp	dd	-1
dump_orig_ss	dd	-1

;------------------------------------------------------------------------------
; for load exp
;------------------------------------------------------------------------------
	align	4
data0		dd	0	; temporary
data1		dd	0	;
data2		dd	0	;
data3		dd	0	;
data4		dd	0	;

file_handle	dd	0
Load_cs		dd	0
Load_ds		dd	0

;##############################################################################
;##############################################################################
