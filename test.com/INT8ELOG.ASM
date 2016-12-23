;
;int 8eh logger for FM-TOWNS
;
; nasm -f bin int8elog.asm -o int8elog.com
;=============================================================================
;※注意※  forrbios.nsd が組み込まれていると .exp 起動時にハングアップします
;=============================================================================
;設定
;=============================================================================
%define	INT_NUMBER	8eh
%define	INT_NUMBER_STR	"008e"
;=============================================================================
;マクロ
;=============================================================================
%imacro	set_cy	0	;Carry set
	push	bp
	mov	bp, sp
	or	w [bp+6], 01h	;Carry セット
	pop	bp
%endmacro

%imacro	clear_cy 0	;Carry reset
	push	bp
	mov	bp, sp
	and	w [bp+6],0feh	;Carry クリア
	pop	bp
%endmacro

%define	s	short
%define	b	byte
%define	w	word
%define	d	dword
%define	offset

%imacro	to_hex	1
	mov	di,offset %1
	call	eax2hex
%endmacro

;=============================================================================
	org	100h
;..start:
	jmp	handler_set

	align	4
handler:
	push	ax
	push	w offset dump_msg
	call	register_dump
	pop	ax
	pop	ax

	pushf
	call	far [cs:original_vector]

	;save_cy
	jc	.set_cy
	clear_cy
	jmp	short .saved
.set_cy:
	set_cy
.saved:

	push	ax
	push	w offset regdump_msg
	call	register_dump
	pop	ax
	pop	ax
	iret
;=============================================================================
;レジスタダンプ
;=============================================================================
	align	4
	; stack
	;	+06h	message offset
	;	+08h	(not use)
	;	+0ah	ip
	;	+0ch	cs
	;	+0eh	flags
register_dump:
	push	ebp
	mov	bp, sp
	push	di
	push	ds	; bp-04
	push	edx	; bp-08
	push	ecx	; bp-0c
	push	ebx	; bp-10
	push	eax	; bp-14

	mov	ax, cs
	mov	ds, ax

	;------------------------------------
	;32 bits registers
	;------------------------------------
	mov	eax, [bp-14h]
	to_hex	reg_eax
	mov	eax, [bp-10h]
	to_hex	reg_ebx
	mov	eax, [bp-0ch]
	to_hex	reg_ecx
	mov	eax, [bp-08h]
	to_hex	reg_edx

	mov	eax, esi
	to_hex	reg_esi
	mov	eax, edi
	to_hex	reg_edi
	mov	eax, [ebp]
	to_hex	reg_ebp

	;------------------------------------
	;segment registers
	;------------------------------------
	mov	ax, [bp-04h]
	to_hex	reg_ds
	mov	eax, es
	to_hex	reg_es
	mov	eax, fs
	to_hex	reg_fs
	mov	eax, gs
	to_hex	reg_gs
	mov	eax, ss
	to_hex	reg_ss

	;------------------------------------
	;special registers
	;------------------------------------
	mov	ax, bp
	add	ax, b 10h
	to_hex	reg_sp

	mov	ax, [bp+0ah]
	to_hex	reg_cs
	mov	ax, [bp+0ch]
	to_hex	reg_ip

	; flags
	mov	ax, [bp+0eh]
	and	al, 01h
	add	al, '0'
	mov	[flag_carry], al

	; Output
	mov	dx,[bp + 06h]
	cmp	dx,offset dump_msg
	je	.step

	push	dx
	mov	dx, offset string_return
	mov	ah, 09h
	int	21h

	pop	dx
	mov	ah, 09h
	int	21h

	mov	dx, offset string_crlf
	mov	ah, 09h
	int	21h
	jmp	.end

.step:
	mov	ah,09h
	int	21h
.end:
	pop	eax
	pop	ebx
	pop	ecx
	pop	edx
	pop	ds
	pop	di
	pop	ebp
	ret

;=============================================================================
;subroutine
;=============================================================================
; EAX を [di] へ１６進数文字列として格納
	align	4
eax2hex:
	mov	bl,[di+4]
	cmp	bl,'_'
	jz	.loop
	shl	eax, 16
.loop:
	mov	ebx, eax
	shr	ebx, 28
	mov	 cl, [hexstr + bx]
	mov	[di], cl
	inc	di
	shl	eax, 4

	mov	bl, [di]
	cmp	bl, ' '
	jz	.end
	cmp	bl, ':'
	jz	.end
	cmp	bl, 13
	jz	.end

	cmp	bl, '_'
	jnz	.loop
	inc	di
	jmp	short .loop
.end:
	ret

;=============================================================================
;DATA
;=============================================================================
;------------------------------------------------------------------
;Int = ####     CS:IP = ####:####                  SS:SP= ####:####
; DS = ####        ES = ####        FS = ####        GS = ####
;EAX = ####_####  EBX = ####_####  ECX = ####_####  EDX = ####_####
;ESI = ####_####  EDI = ####_####  EBP = ####_####  Carry flag = #
;------------------------------------------------------------------
dump_msg	db "----------------------------------------"
		db "--------------------------",13,10
		db "Int = ",INT_NUMBER_STR,"     CS:IP = "
reg_cs		db "####:"
reg_ip		db "####                  SS:SP= "
reg_ss		db "####:"
reg_sp		db "####",13,10
regdump_msg	db " DS = "
reg_ds		db "####        ES = "
reg_es		db "####        FS = "
reg_fs		db "####        GS = "
reg_gs		db "####",13,10,"EAX = "
reg_eax		db "####_####  EBX = "
reg_ebx		db "####_####  ECX = "
reg_ecx		db "####_####  EDX = "
reg_edx		db "####_####",13,10,"ESI = "
reg_esi		db "####_####  EDI = "
reg_edi		db "####_####  EBP = "
reg_ebp		db "####_####  Carry flag = "
flag_carry	db "#",13,10
		db "----------------------------------------"
		db "--------------------------",13,10,'$'
string_return	db '*Ret:*'
string_crlf	db 13,10,'$'

	align	4
hexstr		db	"0123456789ABCDEF"
original_vector	dw 0,0


;=============================================================================
	align	16
handler_set:
	mov	ax,cs
	mov	ds,ax

	;ベクタ読み取り
	mov	ah,35h
	mov	al,INT_NUMBER
	int	21h
	mov	[original_vector   ], bx
	mov	[original_vector +2], es

	;ベクタ設定
	mov	dx,offset handler
	mov	ah,25h
	mov	al,INT_NUMBER
	int	21h

	mov	bx,[ds:02ch]		;PSP より 環境 segment addres 取得 > BX
	mov	ah,49h			;
	mov	es,bx			;
	int	21h			;環境エリア開放

	mov	ah,31h			;常駐終了
	mov	al,0			;RET = 0
	mov	dx,offset handler_set	;DX -> パラグラフサイズ
	shr	dx,4
	int	21h

