;******************************************************************************
; VSYNC counter
;******************************************************************************
;
;[TAB=8]
;------------------------------------------------------------------------------
%ifdef TOWNS
%define VSYNC_MACHINE	'FM-TOWNS'
%define VSYNC_INT_NUM	04Bh
%endif

%ifdef PC98
%define VSYNC_MACHINE	'PC-98'
%define VSYNC_INT_NUM	0Ah
%endif

;------------------------------------------------------------------------------
%imacro	PRINT	1
	mov	edx,%1
	mov	ah,09h
	int	21h
%endmacro

;------------------------------------------------------------------------------

ENTRY:
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

	call	start_vsync


	align	4
count_loop:
	mov	eax, [count]
	mov	edi, NUM
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
; counter handler for FM-TOWNS
;------------------------------------------------------------------------------
%ifdef TOWNS
counter_handler:
	push	edx
	push	eax

	mov	dx,5cah		;VSYNC-���荞�ݗv���N���A���W�X�^
	out	dx,al		;�N���A���W�X�^�ɓK���Ȓl���o��

	mov	al,20h		;bit-5 = 1(EOI bit)
	out	10h,al		;�X���[�u����

	out	6ch,al		;PIC �����A1�ʕb�E�F�C�g���W�X�^�֏�������
	cmc			; �E�G�C�g���W�X�^���Ȃ��ꍇ
	cmc			; ���̂R���߂ŃE�G�C�g�Ƃ���
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

	out	64h,al		;�N���A���W�X�^�ɓK���Ȓl���o��
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
	inc	dword [count]
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
;------------------------------------------------------------------------------

warning		db	'This binary for ',VSYNC_MACHINE,'.',13,10
		db	'push any key for continue.',13,10,'$'
msg		db	13,10,'push any key for stop.',13,10,'$'

cursor_ON	db	27,'[0v$'
cursor_OFF	db	27,'[1v$'

counter_msg	db	'Counter: '
NUM		db	'12345678',13,'$'

	align	4
count		dd	0
dos_vec		dd	0