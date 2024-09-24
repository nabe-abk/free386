;******************************************************************************
; lib for easy benchmark
;******************************************************************************
;[TAB=8]
;
global is_support
global start_vsync
global get_millisec_count
global stop_vsync
global syscall_int21_0Bh
global vram128_write_256byte

;------------------------------------------------------------------------------
%macro	proc4	1
	global	%1
	align	4
%1:
%endmacro
;------------------------------------------------------------------------------
segment	text align=4 class=CODE use32
;------------------------------------------------------------------------------
proc4 is_support
	push	edx

	in	al, 30h		;CPU register
	cmp	al, 0ffh
	jz	.not_fm		;0ffh is not FM series

	mov	dx,020eh	;Drive switch register
	in	al,dx		;
	and	al,0feh		;
	jnz	.not_TOWNS	;all 0 is TOWNS

	; is towns
	mov	byte  [vector_num] , 4Bh		; VSYNC int number
	mov	dword [handler_adr], towns_handler
	mov	eax, 20h
	jmp	.ret

.not_fm:
.not_TOWNS:
	in	al,90h		;FD I/O
	add	al, 1		;cy = al is 0ffh
	jc	.not_98

	in	al,94h		;FD I/O
	add	al, 1		;cy = al is 0ffh
	jc	.not_98

	; is PC-98
	mov	byte  [vector_num] , 0Ah		; VSYNC int number
	mov	dword [handler_adr], pc98_handler
	mov	dword [vram_sel]   , 128h
	mov	eax, 10h
	jmp	.ret

.not_98:
	in	al,0D0h		;DMA Status Register
	add	al, 1		;cy = al is 0ffh
	jc	.not_at

	in	al,0DAh		;DMS I/O
	add	al, 1		;cy = al is 0ffh
	jc	.not_at

	; is PC-AT
	mov	eax, 120h
	verr	ax
	jnz	.not_support

	mov	byte  [is_pc_at], 01
	mov	dword [vram_sel], 120h
	mov	eax, 30h

.ret:
	pop	edx
	ret

.not_at:
.not_support:
	xor	eax, eax
	jmp	.ret

;------------------------------------------------------------------------------
proc4 start_vsync
	pusha
	cmp	byte [is_pc_at], 0
	jnz	.ret

	; save dos vector
	mov	ax, 2503h
	mov	cl, [vector_num]
	int	21h
	mov	[dos_vec], ebx

	; set int vector
	push	ds
	mov	ax, cs
	mov	ds, ax
	mov	edx, [handler_adr]		; handler = ds:edx
	mov	ax, 2506h
	mov	cl, [vector_num]
	int	21h
	pop	ds

	mov	[selector_ds], ds

	; start vsync
	in	al,12h
	and	al,11110111b
	out	12h,al

.ret:
	popa
	ret

;------------------------------------------------------------------------------
proc4 stop_vsync
	pusha
	cmp	byte [is_pc_at], 0
	jnz	.ret

	; mask vsync
	in	al,12h
	or	al,00001000b
	out	12h,al

	; restore dos vector
	mov	ax, 2505h
	mov	cl, [vector_num]
	mov	ebx, [dos_vec]
	int	21h

.ret:
	popa
	ret


;------------------------------------------------------------------------------
proc4 get_millisec_count
	cmp	byte [is_pc_at], 0
	jnz	get_millisec_at

	push	edx

	mov	eax, [count]
	mov	edx, 1092267	; 16.66666ms *2^16
	mul	edx 		; edx:eax ms *2^16
	shld	edx, eax, 16	; edx:eax *2^16
	mov	eax, edx

	pop	edx
	ret


proc4 get_millisec_at
	push	ecx
	push	edx

	xor	eax, eax
	mov	byte [int21_2511.int], 1Ah	; Timer bios
	mov	     [int21_2511.eax], eax	; 

	mov	 ax, 2511h			; call real mode interrupt
	mov	edx, int21_2511
	int	21h

	; ret cs:dx is count
	mov	ax, cx
	shl	eax, 16
	mov	ax, [int21_2511.edx]		; eax = counter

	mov	edx, 3601203	; 54.95ms *2^16
	mul	edx 		; edx:eax ms *2^16
	shld	edx, eax, 16	; edx:eax *2^16
	mov	eax, edx

	pop	edx
	pop	ecx
	ret


;------------------------------------------------------------------------------
proc4 towns_handler
	push	edx
	push	eax

	mov	dx,5cah		;VSYNC-割り込み要因クリアレジスタ
	out	dx,al		;クリアレジスタに適当な値を出力

	mov	al,20h		;bit-5 = 1(EOI bit)
	out	10h,al		;スレーブ側へ

	out	6ch,al		;PIC ｱｸｾｽ、1μ秒ウェイトレジスタへ書き込み
	cmc			; ウエイトレジスタがない場合
	cmc			; この３命令でウエイトとする
	out	00h,al		;bit-5 = 1(EOI bit)

	; count up
	push	ds
	mov	ds, cs:[selector_ds]
	inc	dword [count]
	pop	ds

	pop	eax
	pop	edx
	iret


;------------------------------------------------------------------------------
proc4 pc98_handler
	push	eax

	out	64h,al		;クリアレジスタに適当な値を出力
	mov	al,20h
	out	00h,al		;bit-5 = 1(EOI bit)

	; count up
	push	ds
	mov	ds, cs:[selector_ds]
	inc	dword [count]
	pop	ds

	pop	eax
	iret


;------------------------------------------------------------------------------
proc4 syscall_int21_0Bh
	mov	ah, 0Bh
	int	21h		; ret = AL
	movzx	eax, al
	ret


;------------------------------------------------------------------------------
proc4 vram120_write_256byte
	pusha
	push	es

	mov	ax, [vram_sel]
	verr	ax
	jnz	.not_support
	mov	es, ax

	mov	eax, [esp + 2ch]	;arg2
	mov	edi, [esp + 28h]	;arg1
	mov	ecx, 256/4

	align	4
.loop:
	stosd		; es:[edi] <- eax
	loop	.loop	; not use "rep", because easy for emulation

.not_support:
	pop	es
	popa
	ret


;------------------------------------------------------------------------------
segment	data align=4 class=DATA use32
;------------------------------------------------------------------------------
count		dd	0
selector_ds	dd	0
dos_vec		dd	0
is_pc_at	dd	0

vram_sel	dd	120h
vector_num	dd	0
handler_adr	dd	0

int21_2511:
.int	dw	01Ah
.ds	dw	0b0h
.es	dw	0b0h
.fs	dw	0b0h
.gs	dw	0b0h
.eax	dd	0
.edx	dd	0


