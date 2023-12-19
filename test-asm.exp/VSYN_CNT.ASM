;******************************************************************************
; VSYNC counter
;******************************************************************************
;
;[TAB=8]
;------------------------------------------------------------------------------
%ifdef TOWNS
	%define VSYNC_MACHINE	'FM TOWNS'
	%define VSYNC_INT_NUM	04Bh
	%define	ESC_CURSOL_ON	'[0v$'
	%define ESC_CURSOL_OFF	'[1v$'
%endif

%ifdef PC98
	%define VSYNC_MACHINE	'PC-98'
	%define VSYNC_INT_NUM	0Ah
	%define	ESC_CURSOL_ON	'[>5l'
	%define ESC_CURSOL_OFF	'[>5h'
%endif

;------------------------------------------------------------------------------
%macro	PRINT	1
	mov	edx,%1
	mov	ah,09h
	int	21h
%endmacro

;------------------------------------------------------------------------------
segment	text align=4 class=CODE use32
;------------------------------------------------------------------------------
..start:
	PRINT	warning
	mov	ah,08h			;push any key
	int	21h

	PRINT	msg
	PRINT	cursor_OFF

	; save dos vector
	mov	ax, 2503h
	mov	cl, VSYNC_INT_NUM
	int	21h
	mov	[dos_vec], ebx

	; set int vector
	push	ds
	mov	ax, cs
	mov	ds, ax
	mov	edx,counter_handler		; ds:edx
	mov	ax, 2506h
	mov	cl, VSYNC_INT_NUM
	int	21h
	pop	ds

	mov	[ds_selector], ds
	call	start_vsync

	xor	ebp, ebp	; loop counter

	align	4
count_loop:
	mov	eax, [count]
	mov	edi, count_num
	mov	ecx, 8
	call	decimal_string

	sti
	inc	ebp
	mov	eax, ebp
	mov	edi, loop_num
	mov	ecx, 8
	call	decimal_string

	PRINT	counter_msg

	mov	ah,06h		; check key input
	mov	dl,0ffh		;
	int	21h
	test	al,al
	jz	count_loop

end:
	call	stop_vsync

	; restore dos vector
	mov	ax, 2505h
	mov	cl, VSYNC_INT_NUM
	mov	ebx, [dos_vec]
	int	21h

	PRINT	cursor_ON

	mov	ah,4ch
	xor	al,al
	int	21h


	align	4
;------------------------------------------------------------------------------
; counter handler for FM TOWNS
;------------------------------------------------------------------------------
%ifdef TOWNS
counter_handler:
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

	call	counter_main

	pop	eax
	pop	edx
	iret
%endif

;------------------------------------------------------------------------------
; counter handler for PC-98
;------------------------------------------------------------------------------
%ifdef PC98
counter_handler:
	push	eax

	out	64h,al		;クリアレジスタに適当な値を出力
	mov	al,20h
	out	00h,al		;bit-5 = 1(EOI bit)

	call	counter_main

	pop	eax
	iret
%endif


;------------------------------------------------------------------------------
; counter main
;------------------------------------------------------------------------------
	align	4
counter_main:
	push	ds
	mov	ds, cs:[ds_selector]
	inc	dword [count]
	pop	ds
	ret

;------------------------------------------------------------------------------
; VSYNC
;------------------------------------------------------------------------------
	align	4
start_vsync:
	in	al,12h
	and	al,11110111b
	out	12h,al
	ret

	align	4
stop_vsync:
	in	al,12h
	or	al,00001000b
	out	12h,al
	ret

;------------------------------------------------------------------------------
; decimal string
;------------------------------------------------------------------------------
	align	4
decimal_string:
	push	ebx
	push	edx
	mov	ebx, 10

	align	4
.loop:
	xor	edx, edx
	div	ebx		; edx:eax / 10 = eax, remainder: edx
	add	dl, '0'
	mov	[edi+ecx-1], dl
	loop	.loop

	pop	edx
	pop	ebx
	ret

;------------------------------------------------------------------------------
segment	data align=4 class=DATA use32
;------------------------------------------------------------------------------

warning		db	'This binary for ',VSYNC_MACHINE,'.',13,10
		db	'push any key for continue.',13,10,'$'
msg		db	13,10,'push any key for stop.',13,10,'$'

cursor_ON	db	27,ESC_CURSOL_ON
cursor_OFF	db	27,ESC_CURSOL_OFF

counter_msg	db	'Counter: '
count_num	db	'12345678 / loop: ',
loop_num	db	'12345678',13,'$'

	align	4
count		dd	0
dos_vec		dd	0

ds_selector	dd	0

