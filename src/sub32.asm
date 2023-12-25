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
global	dump_orig_eax
global	dump_orig_ds
global	dump_orig_esp
global	dump_orig_ss
;------------------------------------------------------------------------------

seg32	text32 class=CODE align=4 use32
;##############################################################################
;register dump
;##############################################################################
;------------------------------------------------------------------------------
proc32 register_dump_iret
;------------------------------------------------------------------------------
	;	+08h eflags
	;	+04h cs
	; stack	+00h eip
	push	eax				; error code       is dummy
	push	eax				; interrupt number is dummy
	push	offset set_dump_head_is_reg	; callback function
	push	ds
	push	eax

	push	F386_ds
	pop	ds

	mov	eax, esp
	add	eax, 4 * 8
	mov	[dump_orig_esp], eax
	push	ss
	pop	dword [dump_orig_ss]

	; stack
	;	+1ch	eflags
	;	+18h	cs
	;	+14h	eip
	;	+10h	error code
	;	+0ch	interrupt number
	;	+08h	header handler address
	;	+04h	ds
	;	+00h	eax
	call	register_dump

	pop	eax
	pop	ds
	add	esp, 4 * 3
	iret


;------------------------------------------------------------------------------
proc32 set_dump_head_is_reg
;------------------------------------------------------------------------------
	; edi = ebp = buffer address
	mov	esi, offset regdump_hr
	call	copy_esi_to_edi
	mov	esi, offset dump_head_reg
	call	copy_esi_to_edi
	ret

;------------------------------------------------------------------------------
proc32 set_dump_head_is_fault
;------------------------------------------------------------------------------
	; ebx = int number
	; edx = error code
	; edi = ebp = buffer address
	;
	mov	esi, offset regdump_hr
	call	copy_esi_to_edi

	mov	esi, offset dump_head_fault
	call	copy_esi_to_edi

	push	edi
	mov	edi, ebp
	mov	eax, ebx
	call	rewrite_next_hash_to_hex	; int number

	add	edi, byte 4
	;
	; copy exception name
	;
	cmp	ebx, byte 11h
	ja	.unknown

	mov	esi, offset cpu_fault_name_table
.loop:
	test	ebx, ebx
	jz	short .copy_name
.zero_loop:
	lodsb
	test	al,al
	jnz	.zero_loop	; find 0
	dec	ebx
	jmp	short .loop
.unknown:
	mov	esi, offset cpu_fault_unknown
.copy_name:
	call	copy_esi_to_edi

	mov	eax, edx
	call	rewrite_next_hash_to_hex	; error code
	pop	edi
	ret

;------------------------------------------------------------------------------
proc32 copy_esi_to_edi
;------------------------------------------------------------------------------
.loop:
	lodsb
	test	al,al
	jz	.ret
	stosb
	jmp	short .loop
.ret:
	ret

;##############################################################################
; register dump main
;	original code by kattyo@ABK  2000/07/24
;##############################################################################
; in	 ds = F386_ds
; out	eax = destroy
;
proc32 register_dump
	call	get_gp_buffer_32
	test	eax, eax
	jnz	.step		; success
	ret			; alloc error
	;stack
	;	+20h	eflags
	;	+1ch	cs
	;	+18h	eip
	;	+14h	error code
	;	+10h	interrupt number
	;	+0ch	header handler address
	;	+08h	ds
	;	+04h	eax
	;memory
	;	[dump_orig_esp]
	;	[dump_orig_ss]
.step:
	cld
	pusha					; 20h bytes
	push	es
	%assign buf_adr		-4		; buffer address (eax)
	%assign	sdiff		 24h

	mov	eax, cr3
	push	eax
	mov	eax, cr2
	push	eax
	mov	eax, cr0
	push	eax				; 0ch bytes

	%assign	sdiff	sdiff + 0ch

	push	dword [esp + sdiff + 20h]	; eflags
	push	ebp
	push	edi
	push	esi				; esi

	push	edx
	push	ecx
	push	ebx

	%assign	sdiff	sdiff + 1ch

	push	dword [esp + sdiff + 04h]	; eax
	push	gs
	push	fs
	push	es

	%assign	sdiff	sdiff + 10h

	push	dword [esp + sdiff + 08h]	; ds
	push	dword [dump_orig_esp]
	push	dword [dump_orig_ss]

	%assign	sdiff	sdiff + 0ch

	push	dword [esp + sdiff + 18h]	; eip
	%assign	sdiff	sdiff + 04h
	push	dword [esp + sdiff + 1ch]	; cs
	%assign	sdiff	sdiff + 04h

	push	ds
	pop	es				; set es

	;------------------------------------------------------------
	; set flags
	;------------------------------------------------------------
	mov	eax, [esp + sdiff + 20h]	; eflags
	mov	edx, offset regdump_flags +1
	mov	 cl, '0'

	test	al, 01h		; Carry
	setnz	bl
	or	bl, cl
	mov	[edx + 3*0],bl

	test	al, 04h		; Parity
	setnz	bl
	or	bl, cl
	mov	[edx + 3*1],bl

	test	al, 40h		; Zero
	setnz	bl
	or	bl, cl
	mov	[edx + 3*2],bl

	test	al, 80h		; Sign
	setnz	bl
	or	bl, cl
	mov	[edx + 3*3],bl

	test	ah, 08h		; Overflow
	setnz	bl
	or	bl, cl
	mov	[edx + 3*4],bl

	test	ah, 04h		; Direction / DF
	setnz	bl
	or	bl, cl
	mov	[edx + 3*5],bl

	test	ah, 02h		; Interrupt Enable / IF
	setnz	bl
	or	bl, cl
	mov	[edx + 3*6],bl

	;------------------------------------------------------------
	; make message data
	;------------------------------------------------------------
	mov	ebp, [esp + sdiff + buf_adr]	; save buffer pointer
	mov	edi, ebp

	mov	ebx, [esp + sdiff + 10h]	; interrupt number
	mov	ecx, [esp + sdiff + 14h]	; error code

	call	near [esp + sdiff + 0ch]	; header set handler

	push	edi
	mov	esi, offset regdump_msg
	call	copy_esi_to_edi			; regdump message
	mov	byte [edi], '$'			; end mark for PRINT
	pop	edi

	;------------------------------------------------------------
	; rewrite register value
	;------------------------------------------------------------
	mov	ecx, 19
.loop_regs:
	pop	eax
	call	rewrite_next_hash_to_hex
	loop	.loop_regs

	PRINT32	ebp

	; free buffer
	mov	eax, ebp
	call	free_gp_buffer_32

	pop	es
	popa
	ret


;##############################################################################
; register dump for interrupt hook
;##############################################################################
%if INT_HOOK
;------------------------------------------------------------------------------
proc32 set_dump_head_is_int
;------------------------------------------------------------------------------
	; ecx = error code
	; edi = ebp = buffer address
	mov	esi, offset regdump_hr
	call	copy_esi_to_edi

	mov	esi, offset dump_head_int
	call	copy_esi_to_edi

	push	edi
	mov	edi, ebp
	mov	eax, ecx
	call	rewrite_next_hash_to_hex	; rewrite int number
	pop	edi
	ret

%if INT_HOOK_RETV
;------------------------------------------------------------------------------
proc32 set_dump_head_is_return
;------------------------------------------------------------------------------
	; ecx = error code
	; edi = ebp = buffer address
	mov	esi, offset dump_head_ret
	call	copy_esi_to_edi
	ret
%endif

;------------------------------------------------------------------------------
proc32 register_dump_from_int
;------------------------------------------------------------------------------
	push	set_dump_head_is_int
	push	ds
	push	eax
	;
	;stack
	;	+1ch	eflags
	;	+18h	cs
	;	+14h	eip
	;	+10h	int number
	;	+0ch	caller
	;	+08h	set header handler
	;	+04h	ds
	;	+00h	eax
	;
	%assign	cs_diff		18h
	%assign	intnum_diff 	10h
	%assign	ah_diff 	01h

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
		cmp	w [esp + cs_diff], INT_HOOK_CS
		jne	short .no_dump
	%endif
	;
	; exclude CS
	;
	%if INT_HOOK_EX_CS
		cmp	w [esp + cs_diff], INT_HOOK_EX_CS
		je	short .no_dump
	%endif
	;
	; Free386 internal call ignore
	;
	%if !INT_HOOK_F386
		cmp	w [esp + cs_diff], F386_cs
		je	short .no_dump
	%endif
	;
	; int 21h, ah=09h is ignore
	;
	cmp	b [esp + intnum_diff], 21h
	jnz	short .do_dump
	cmp	ah, 09h
	jz	short .no_dump
.do_dump:
	; stack
	;	+1ch	eflags
	;	+18h	cs
	;	+14h	eip
	;	+10h	int number
	;	+0ch	caller
	;	+08h	set header handler
	;	+04h	ds
	;	+00h	eax
	mov	eax, esp
	add	eax, 20h
	mov	[dump_orig_esp], eax
	push	ss
	pop	dword [dump_orig_ss]

	call	register_dump

	%if INT_HOOK_RETV
		cmp	b [esp + ah_diff],    4ch	; ah!=4ch
		jne	.do_dump_ret
		cmp	b [esp + intnum_diff],21h	; int 21h
		je	.no_dump
	.do_dump_ret:
		cmp	b [.in_dump], 0
		jnz	.no_dump
		mov	b [.in_dump], 1

		mov	eax, [esp + 14h]
		mov	[.orig_eip], eax
		mov	eax, [esp + 18h]
		mov	[.orig_cs],  eax
		mov	d [esp+14h], offset .int_retern
		mov	  [esp+18h], cs
	%endif

.no_dump:
	pop	eax
	pop	ds
	add	esp, byte 4		; <-- push set_dump_head_is_int
	ret

%if INT_HOOK_RETV
	align 4
.int_retern:
	pushf
	push	d [cs:.orig_cs]
	push	d [cs:.orig_eip]
	push	eax			; int number is dummy
	push	eax			; error code is dummy
	push	set_dump_head_is_return	; dump header handler
	push	ds
	push	eax

	push	d F386_ds
	pop	ds
	mov	b [.in_dump], 0

	mov	eax, esp
	add	eax, 20h
	mov	[dump_orig_esp], eax
	push	ss
	pop	dword [dump_orig_ss]

	call	register_dump

	pop	eax
	pop	ds
	add	esp, 0ch
	iret

	align	4
.in_dump	dd	0
.orig_eip	dd	0
.orig_cs	dd	0
%endif
%endif

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
proc32 search_path_env
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
	jc	.file_open_error	;Cy=1 ならオープンエラー

	mov	ebx,eax			;bx <- file handl番号
	mov	[file_handle],eax	;同じくメモリにも記録

	;
	;ヘッダ部ロード
	;
	mov	edx,esi			;ワークアドレス
	mov	ecx,200h		;読み込むバイト数
	mov	ah,3fh			;file read ->ds:edx
	int	21h			;dos call
	jc	.file_read_error	;Cy=1 ならリードエラー

	;
	;ヘッダ部解析
	;
	mov	eax,[esi]
	cmp	eax,00013350H		;P3 形式['P3']・フラットモデル[w (0001)]
	jne	.load_MZ_exp		;P3 でなければ MZヘッダか確認 (jmp)

	;
	;必要なメモリ算出
	;
	mov	ecx,[esi+74h]		;ecx = program image size
	mov	eax,[esi+56h]		;eax = mindata
	call	.calc_4Kmem_eax_ecx
	mov	[5ch],eax		;save to PSP

	mov	eax,[esi+5ah]		;eax = maxdata
	call	.calc_4Kmem_eax_ecx
	shr	eax,12			;4KB pages

	push	esi
	mov	ecx,eax			;ecx = allocation pages (max)
	mov	esi,[esi+5eh]		;esi = base memory address
	call	make_cs_ds		;
	pop	esi
	jc	.not_enough_memory	;error

	;
	;メモリ量チェック
	;
	mov	ebx,[60h]		;実際に割り当てたメモリ [byte]
	mov	eax,[5ch]		;PSP に記録 / 最低限必要なメモリ [byte]
	cmp	ebx,eax			;値比較
	jb	.not_enough_memory	;負数ならメモリ不足

	sub	ebx,[esi+74h]		;ロードイメージの大きさを引く
	mov	[64h],ebx		;ヒープメモリ総量を PSPに記録

	;
	;ロードプログラムのスタックと実行開始アドレスを記録
	;
	mov	eax,[esi + 62h]	;スタックポインタ
	mov	ebx,[esi + 68h]	;実行開始アドレス
	mov	[tmp03],eax	;esp
	mov	[tmp04],ebx	;eip

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
	jnz	exp_un_pack_fread	;PACK を解きながらファイル読み込み
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
	mov	ebp,[tmp03]		;esp
	mov	edx,[tmp04]		;eip
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


proc32 .calc_4Kmem_eax_ecx
	; in eax + ecx
	add	eax, ecx
	jc	.over
.step:	add	eax,      0fffh		; round up 4KB
	jc	.over
	and	eax, 0fffff000h	
	ret

.over	mov	eax, 0fffff000h
	ret


;----------------------------------------------------------------------
;○MZ ヘッダを持つ EXP ファイルのロード
;----------------------------------------------------------------------
;	mov	eax,[esi]
;	cmp	eax,00013350H	;P3 形式['P3']・フラットモデル[w (0001)]
;	jne	check_MZ	;P3 でなければ MZヘッダか確認 (jmp)
;
proc32 .load_MZ_exp

	;////////////////////////////////////////////////////
	;MZ(MP) ヘッダに対応しない場合
	;////////////////////////////////////////////////////
%if USE_MZ_EXP = 0
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

	movzx	ebx,w [esi+0ah]	;+0A w "mindata / 4KB"
	shl	ebx,12
	add	ebx, eax	;minimum memory size (byte)
	mov	[5ch], ebx

	movzx	ecx,w [esi+0ch]	;+0C w "maxdata / 4KB"
	shr	eax,12		;eax = load image pages

	push	esi
	add	ecx,eax			;ecx = allocate max pages
	xor	esi,esi			;esi = base offset address
	call	make_cs_ds
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
	mov	[tmp03],eax	;esp
	mov	[tmp04],ebx	;eip

	;
	;以下、P3 のコピー
	;
	mov	ebx,[file_handle]	;ebx <- ファイルハンドル番号ロード
	xor	ecx,ecx			;ecx = 0
	;mov	edx,---		;代入済	;edx = プログラムイメージまでの offset
	mov	ax,4200h		;ファイル先頭からポインタ移動
	int	21h			;DOS call（file pointer = cx:dx）
	jc	.file_read_error	;Cy=1 なら エラー

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
	mov	[tmp01],eax	;このプログラム
	mov	[tmp02],ecx	;読み込み先

	;
	;↑により ds がこのセグメントを示すようになった
	;
	mov	edi,edx			;edi <- ファイル読み込み先
	mov	edx,esi			;edx <- ワークメモリ
	mov	[tmp00],esi		;汎用変数に一時的に記憶


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

	mov	 ds, [tmp02]		;ds = ファイルロード領域

	;
	;ds:edx = プログラムロード領域
	;
	mov	ah,3fh			;file read
	int	21h			;DOS コール
	jc	short exp_up_fread_err	;キャリーがあればリードエラー

	mov	 ds, [cs:tmp01]		;このプログラムの ds
	mov	edx, [tmp00]		;ワークエリアオフセットを戻す
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
	mov	 es,[tmp01]	;このプログラム
	mov	 ds,[tmp02]	;ロード領域

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
	jb	.no_memory		;マイナスならエラー
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
segdata	data class=DATA align=4
		   ;                         12345678901234567890123456789012345678901
dump_head_fault	db "CPU Expection: INT ##h -                                          ",13,10,
		db "Err = ####_####  ",0
dump_head_int	db "Int = ###h       ",0
dump_head_ret	db "Return:          ",0
dump_head_reg	db "Register dump:   ",0
regdump_msg	db                   "CS:EIP = ####:####_####  SS:ESP = ####:####_####",13,10,
		db " DS = ####  ES = ####  FS = ####  GS = ####   "
regdump_flags	db "C  P  Z  S  O  D  I ",13,10,
		db "EAX = ####_####  EBX = ####_####  ECX = ####_####  EDX = ####_####",13,10,
		db "ESI = ####_####  EDI = ####_####  EBP = ####_####  FLG = ####_####",13,10,
		db "CR0 = ####_####  CR2 = ####_####  CR3 = ####_####",13,10
regdump_hr	db "------------------------------------------------------------------",13,10,0

cpu_fault_name_table:
			;12345678901234567890123456789012345678901 : max 41 byte
.err_00		db	'Zero Divide Error',0
.err_01		db	'Debug Exceptions',0
.err_02		db	'NMI',0
.err_03		db	'Breakpoint',0
.err_04		db	'INTO Overflow',0
.err_05		db	'Bounds Check Fault',0
.err_06		db	'Invalid Opcode Fault',0
.err_07		db	'Coprocessor Not Available',0
.err_08		db	'Double Fault',0
.err_09		db	'Coprocessor Segment Overrun',0
.err_0a		db	'Invalid TSS',0
.err_0b		db	'Segment Not Present Fault',0
.err_0c		db	'Stack Exception Fault',0
.err_0d		db	'General Protection Exception',0
.err_0e		db	'Page Fault',0
.err_0f		db	'(CPU RESERVED)',0
.err_10		db	'Coprocessor Error',0
.err_11		db	'Alignment Fault',0
cpu_fault_unknown:
		db	'Unknown',0

	align	4
dump_orig_esp	dd	0
dump_orig_ss	dd	0

;------------------------------------------------------------------------------
; for load exp
;------------------------------------------------------------------------------
	align	4
tmp00		dd	0	; temporary
tmp01		dd	0	;
tmp02		dd	0	;
tmp03		dd	0	;
tmp04		dd	0	;

file_handle	dd	0
Load_cs		dd	0
Load_ds		dd	0

;##############################################################################
;##############################################################################
