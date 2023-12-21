;******************************************************************************
;�@Free386	FM TOWNS dependent code
;******************************************************************************
;
seg16	text class=CODE align=4 use16
;==============================================================================
;��TOWNS �ȈՃ`�F�b�N
;==============================================================================
;Ret	Cy=0	TOWNS ��������Ȃ�
;	Cy=1	TOWNS �łȂ�����?
;
proc32 check_TOWNS_16
	in	al,30h		;CPU ���ʃ��W�X�^
	test	al,al		;=and�^�l check
	jz	.not_fm		;0 �Ȃ� FM �V���[�Y�łȂ�
	inc	al		;+1 ����
	jz	.not_fm		;0ffh �ł� FM �V���[�Y�łȂ�

	;FM ������ TOWNS??
	mov	dx,020eh	;�h���C�u�X�C�b�`���W�X�^(TOWNS �̂�)
	in	al,dx		;����FD �� �O�tFD �������ł���
	and	al,0feh		;bit 7�`1 �� and ����
	jnz	.not_TOWNS	;all 0 �łȂ���� TOWNS �ł͂Ȃ�

	clc	;����
	ret

.not_fm:
.not_TOWNS:
	stc	;���s
	ret

;==============================================================================
;��CoCo���̕ۑ�
;==============================================================================
; ��CALL�o�b�t�@�ɕۑ�����
;
proc32 init_TOWNS_16
	;
	; 386SX����
	;
	in	al, 30h
	cmp	al, 03h			; 386SX
	jne	.skip_386sx
	mov	b [cpu_is_386sx], 1
.skip_386sx:
	;
	; VCPI��񂩂瑍�������e�ʂ̏C��
	;
	in	al, 31h
	cmp	ax, 01h			; ����TOWNS
	je	.skip

	xor	eax, eax
	mov	dx, 5e8h		; �������e�ʃ��W�X�^�i����ɂ͂Ȃ��j
	in	al, dx			; al MB
	and	al, 07fh
	shl	eax, 8			; MB to pages
	mov	[all_mem_pages], eax
.skip:
	;------------------------------------------
	;init NSDD
	;------------------------------------------
	cmp	b [load_nsdd], 0
	je	short .no_nsdd

	call	init_CoCo
.no_nsdd:
	ret

;==============================================================================
;��CoCo���̕ۑ�
;==============================================================================
; ��CALL�o�b�t�@�ɕۑ�����
proc32 init_CoCo
	mov	ax, 0c000h	; CoCo���݊m�F
	int	8eh
	test	ah, ah
	jnz	.fail

	cmp	bh, 32h
	jb	.fail
	cmp	cx, 436fh	; 'Co'
	jne	.fail
	cmp	dx, 436fh	; 'Co'
	jne	.fail
	cmp	si, 204bh	; ' K'
	jne	.fail
	cmp	di, 656eh	; 'en'
	jne	.fail

	; int 8eh ax=c10ch
	;	�@�\�s�������A������o�^���Ă���B
	;	���̏��������Ȃ��� TMENU.EXG ���N�����Ȃ��B
	;	�d���Ȃ��̂ŁARUN386�̒l���R�s�[���萔�ŏ����B
	mov	ax, 0c10ch
	mov	cx, 2
	mov	si, 0
	mov	dx, 0b107h
	int	8eh

	;
	; [Regist] real mode to 32bit mode far call routine
	;
	mov	dx, cs
	mov	bx, offset callf32_from_V86
	mov	ax, 0c207h
	int	8eh

	ret

.fail:
	mov	b [load_nsdd], 0
	ret


BITS	32
;==============================================================================
;��T-OS �̃���������ݒ�
;==============================================================================
proc32 init_TOWNS_32
	mov	ebx,offset T_OS_memory_map

	mov	al, [cpu_is_386sx]
	test	al, al
	jz	.skip
	mov	ebx,offset T_OS_memory_map_386sx
.skip:
	call	map_memory			;

	mov	esi,offset T_OS_selector_alias	;�G�C���A�X�̍쐬
	call	make_aliases			;

	;------------------------------------------
	;T-BIOS �̒���� / thanks to Mamiya (san)
	;------------------------------------------
	;port(0x3b90) TBIOS�����A�h���X
	;port(0x3b98) TBIOS�T�C�Y
	;port(0x3ad0) TBIOS���[�N�����A�h���X(512byte)

	mov	dx,3b90h		;T-BIOS �x�[�X�A�h���X�ǂݏo��
	call	TOWNS_CMOS_READ		;ebx <- READ
	mov	esi,ebx			;esi = address

	mov	dx,3b98h		;T-BIOS �T�C�Y�ǂݏo��
	call	TOWNS_CMOS_READ		;ebx <- READ
	dec	ebx			;ebx = limit

	;/// �Z���N�^�쐬 //////
	mov	edi,[work_adr]		;���[�N������
	mov	d [edi  ],esi		;base
	mov	d [edi+4],ebx		;limit

	mov	d [edi+8],0a00h		;R/X / �������x��=0
	mov	eax,TBIOS_cs		;�S�������A�N�Z�X�Z���N�^
	call	make_selector		;�������Z���N�^�쐬 edi=�\���� eax=sel

	mov	d [edi+8],0200h		;R/W / �������x��=0
	mov	eax,TBIOS_ds		;�S�������A�N�Z�X�Z���N�^
	call	make_selector		;�������Z���N�^�쐬 edi=�\���� eax=sel

	;------------------------------------------
	;VRAM�̏��������`�F�b�N�p�̒l
	;------------------------------------------
	mov	edi,[GDT_adr]		;GDT �A�h���X���[�h
	mov	 al,[edi + F386_ds +5]	;�^�C�v�t�B�[���h���[�h
	test	 al,01
	jnz	.not_emulator

	push	es
	mov	b [is_emulator], 1
	mov	ebx, 128h
	mov	es, bx
	mov	d [es:07fffch], 011011011h
	pop	es
.not_emulator:

	;------------------------------------------
	;wakeup NSDD
	;------------------------------------------
	cmp	b [load_nsdd], 0
	je	short .no_nsdd

	call	wakeup_nsdd
.no_nsdd:
	ret

;------------------------------------------------------------------------------
; NSD driver setup and wakeup
;------------------------------------------------------------------------------
proc32 wakeup_nsdd
	mov	eax, LDT_sel
	mov	  fs,ax

	xor	ebx, ebx
	xor	edx, edx
	xor	ebp, ebp	; ebp = 0
.loop:
	mov	 ax, 0c103h	; get NSD driver info
	mov	ecx, ebp	; cx = driver number
	mov	edi, [work_adr]
	int	8eh
	test	ah, ah
	jnz	.exit

	; cx = Num of drivers(n)
	; bx = cs (LDT)
	; dx = ds (LDT)
	; [ds:edi]
	;	 LDT Format, limit byte
	;	 FF 7F 00 80  21 9A 40 00 - FF 7F 00 80  21 92 40 00
	;	 4C 00 00 00  00 00 00 00 - 44 00 00 00  00 00 00 00
	;
	mov	esi, ebx
	mov	eax, [edi]
	mov	[fs:esi-4], eax		; selector=44h, access to 40h
	mov	eax, [edi+04h]
	mov	[fs:esi  ], eax		; selector=44h, access to 44h

	mov	esi, edx
	mov	eax, [edi+08h]
	mov	[fs:esi-4], eax		; selector=3Ch, access to 38h
	mov	eax, [edi+0ch]
	mov	[fs:esi  ], eax		; selector=3Ch, access to 3Ch

	mov	 al, NSDD_wakeup
	call	send_command_to_nsdd

	inc	ebp
	jmp	.loop

.exit:
	ret


proc32 send_command_to_nsdd
	;  al = command
	; ebx = code selector
	push	gs
	push	ebx
	push	edi

	mov	edi, [work_adr]
	mov	 gs,bx
	mov	[edi+4], ebx

	movzx	ebx, w [gs:NSDD_stra_adr]	; +06h  strategy  entry
	mov	[edi], ebx

	mov	ebx, edi
	add	ebx, 10h
	mov	w [ebx], 000dh
	mov	[ebx+2], al			; save command code

	call	far [edi]			; call strategy


	movzx	eax, w [gs:NSDD_intr_adr]	; +08h  interrupt entry
	mov	[edi], eax

	call	far [edi]			; call interrupt

	pop	edi
	pop	ebx
	pop	gs
	ret

;------------------------------------------------------------------------------
;��TOWNS �� C-MOS dword �ǂݏo��
;------------------------------------------------------------------------------
	align	4
TOWNS_CMOS_READ:
	add	edx,byte 6	;+3 byte �̈ʒu
	in	al,dx		;(C-MOS �͋����Ԓn�ɒ�����Ă���)
	mov	bh,al
	sub	edx,byte 2

	in	al,dx		;+2 byte �̈ʒu
	mov	bl,al
	sub	edx,byte 2

	shl	ebx,16

	in	al,dx		;+1 byte �̈ʒu
	mov	bh,al
	sub	edx,byte 2

	in	al,dx		;+0 byte / �w��Ԓn
	mov	bl,al
	ret


;==============================================================================
;��TOWNS �̏I������
;==============================================================================
proc32 exit_TOWNS_32
	;------------------------------------------
	;NSDD �I������
	;------------------------------------------
	cmp	b [load_nsdd], 0
	je	short .no_nsdd

	mov	b [load_nsdd], 0	;�ē��h�~
	call	sleep_nsdd		;NSD�h���C�o���~������
.no_nsdd:

	;--------------------------------------------------------
	;��ʂ̏�����
	;--------------------------------------------------------
	mov	al,[reset_CRTC]		;reset / 1 = ������, 2 = CRTC�̂�
	test	al,al			;0 ?   / 3 = �����F��
	jz	near .no_reset		;�Ȃ�Ώ���������

	;*** CRTC �̏����� ***
	cmp	al,3			;�����F�� ?
	jne	.res_c			; �łȂ���� jmp

	;*** VRAM������������Ă���H ***
	cmp	b [is_emulator], 0
	je	.not_emulator

	push	es
	mov	ebx, 128h
	mov	es, bx
	mov	eax, [es:07fffch]
	pop	es

	mov	 bl, 1			;reset VRAM flag
	cmp	eax, 011011011h
	jne	.res_c

.not_emulator:
	;*** check VRAM access bit ***
	mov	edi,[GDT_adr]		;GDT �A�h���X���[�h
	mov	esi,[LDT_adr]		;LDT �A�h���X���[�h
	mov	 al,[edi + TBIOS_cs +5]	;�^�C�v�t�B�[���h���[�h
	mov	 bl,[esi + 120h   +5]	;GDT:VRAM (16/32k)
	or	 bl,[esi + 128h   +5]	;GDT:VRAM (256)
	or	 bl,[esi + 104h-4 +5]	;LDT:VRAM (16/32k)
	or	 bl,[esi + 10ch-4 +5]	;LDT:VRAM (256)
	or	al,bl
	test	al,01			;�A�N�Z�X���� ?
	jz	.no_reset_CRTC		;0 �Ȃ� T-BIOS ���g�p (jmp)
.res_c:
	push	ebx
	call	TOWNS_DOS_CRTC_init	;CRTC ������
	pop	ebx

.no_reset_CRTC:

	;*** VRAM �̏����� ***
	mov	al,[reset_CRTC]
	cmp	al,2			;VRAM �͏��������Ȃ� ?
	je	.no_reset_VRAM		;��������� jmp
	cmp	al,1			;�K�������� ?
	je	.res_v			;��������� jmp

	test	bl,01			;VRAM�� �A�N�Z�X���� ?
	jz	.no_reset_VRAM		;0 �Ȃ� VRAM ���g�p (jmp)

.res_v:	push	es
	mov	eax,120h		;VRAM �Z���N�^
	mov	  es,ax			;Load
	xor	edi,edi			;edi = 0
	mov	ecx,512*1024 / 4	;512 KB
	xor	eax,eax			;�h��Ԃ��l
	rep	stosd			;0 �N���A
	pop	es
.no_reset_VRAM:
.no_reset:
	ret

;------------------------------------------------------------------------------
;��NSD�h���C�o�� sleep ������
;------------------------------------------------------------------------------
proc32 sleep_nsdd
	mov	ax, 0c003h
	int	8eh
	test	ah, ah
	jnz	.exit

	mov	ebp, ecx	; ebp=�풓�h���C�o�̐�
	xor	ebx, ebx

.loop:
	test	ebp, ebp
	jz	.exit
	dec	ebp

	mov	 ax, 0c103h	; �풓�h���C�o�̏��擾
	mov	ecx, ebp	; cx = �풓�h���C�o�ԍ�
	mov	edi, [work_adr]
	int	8eh
	test	ah, ah
	jnz	.loop

	; cx = Num of drivers(n)
	; bx = cs (LDT)
	; dx = ds (LDT)

	mov	al, NSDD_sleep
	call 	send_command_to_nsdd
		;  al = command
		; ebx = code selector

	jmp	short .loop
.exit:
	ret


;------------------------------------------------------------------------------
;��CRTC ������
;------------------------------------------------------------------------------
;	Special thanks to �肤�� (CRTC����f�[�^)
;
	align	4
TOWNS_DOS_CRTC_init:
	;///////////////////////////////
	;/// ��ʏo��off ///////////////
	mov	dx,0FDA0h	;�o�͐��䃌�W�X�^
	xor	al,al		;al
	out	dx,al		;��ʏo��off

	;///////////////////////////////
	;/// CRTC ���W�X�^�̑��� ///////
	mov	ebx,offset TOWNS_CRTC_data
	xor	ecx,ecx
	mov	dh,4h		;CRTC ���W�X�^�̏�ʃr�b�g

	align	4
.loop1:
	mov	dl,40h		;CRTC �A�h���X���W�X�^ (dx=440h)
	mov	al,cl		;�A�h���X�ԍ�
	out	dx,al		;�A�h���X�o��
	inc	cl		;�A�h���X�X�V

	mov	dl,42h		;CRTC �f�[�^���W�X�^ (dx=442h)
	mov	ax,[ebx]	;�e�[�u������o�͒l�ǂݏo��
	out	dx,ax		;word �o��
	add	ebx,byte 2	;�A�h���X�X�V

	cmp	cl,20h		;�I���l ?
	jne	.loop1

	;///////////////////////////////
	;/// CRTC �o�̓��W�X�^�̑��� ///
	mov	dl,48h		;CRTC �o�̓��W�X�^�E�R�}���h (dx=448h)
	mov	al,00h		;�A�h���X = 0
	out	dx,al
	mov	dl,4ah		;CRTC �o�̓��W�X�^�E�f�[�^ (dx=44ah)
	mov	al,15h		;�R�}���h = 15h
	out	dx,al

	mov	dl,48h		;CRTC �o�̓��W�X�^�E�R�}���h (dx=448h)
	out	dx,al		;�A�h���X = 1
	mov	dl,4ah		;CRTC �o�̓��W�X�^�E�f�[�^ (dx=44ah)
	mov	al,09h		;�R�}���h = 09h
	out	dx,al		;

	;///////////////////////////////
	;/// �p���b�g�̐ݒ� ////////////
	mov	ah,08h				;Layer 0
	mov	ebx, offset TOWNS_PAL_layer0	;�p���b�g�f�[�^
	call	.setPalette16

	mov	ah,28h				;Layer 1
	mov	ebx, offset TOWNS_PAL_layer1	;�p���b�g�f�[�^
	call	.setPalette16

	;///////////////////////////////
	;/// FM-R�݊��o�͂̐ݒ� ////////
	mov	dx,0ff81h	;FM-R display I/O
	mov	al,0fh
	out	dx,al

	mov	dl,82h		;dx = ff82h
	mov	al,67h
	out	dx,al

	mov	dx,458h		;
	xor	al,al		;al = 0
	out	dx,al
	mov	dl,5ah
	mov	eax,0ffffffffh	
	out	dx,eax

	mov	dx,458h		;
	mov	al,1		;al = 1
	out	dx,al
	mov	dl,5ah
	mov	eax,0ffffffffh	
	out	dx,eax

	;///////////////////////////////
	;/// ��ʏo��on ////////////////
	mov	dx,0FDA0h	;�o�͐��䃌�W�X�^
	mov	al,0fh		;bit 3,2 = layer0 / bit 1,0 = layer1
	out	dx,al		;��ʏo��off

	;///////////////////////////////
	;/// FM�����^�C�}���X�^�[�g ////
	;�{���� inp(4d8h) & 80h �� busy �m�F���ׂ��Ȃ̂����c�c
	;
	mov	dx,04d8h	;FM�����A�h���X���W�X�^
	mov	al,2bh		;�A�h���X
	out	dx,al		;�f�[�^�o��
	out	6ch,al		;1us-Wait
	mov	dl,0dah		;FM�����f�[�^���W�X�^
	mov	al,2ah		;�o�͒l
	out	dx,al		;�f�[�^�o��
	out	6ch,al		;1us-Wait

	mov	dl,0d8h		;FM�����A�h���X���W�X�^
	mov	al,27h		;�A�h���X
	out	dx,al		;�f�[�^�o��
	out	6ch,al		;1us-Wait
	mov	dl,0dah		;FM�����f�[�^���W�X�^
	mov	al,2ah		;�o�͒l
	out	dx,al		;�f�[�^�o��
	ret

	;/////////////////////////////////////////////////////////////
	;�p���b�g�ݒ胋�[�`��
	;/////////////////////////////////////////////////////////////
	align	4
.setPalette16:
	mov	dx,448h		;CRTC�o�̓��W�X�^����
	mov	al,01h		;
	out	dx,al		;����y�[�W�̐ݒ�

	mov	dl,4ah		;CRTC�o�̓��W�X�^����
	mov	al,ah		;����y�[�W�̃��[�h
	out	dx,al		;

	xor	ecx,ecx		;ecx = 0
	mov	dh,0fdh		;�p���b�g���W�X�^�̏�ʃr�b�g

	align	4
.loop2:
	mov	al,cl		;�p���b�g�ԍ�
	mov	dl,90h		;
	out	dx,al

	inc	cl		;�p���b�g�ԍ��X�V
	mov	si,[ebx]	;�p���b�g�f�[�^���[�h
	add	ebx,byte 2	;�A�h���X�X�V

	mov	eax,esi		;�p���b�g�f�[�^
	shl	eax,4		;
	mov	dl,92h		;blue
	out	dx,al

	mov	eax,esi		;�p���b�g�f�[�^
	mov	dl,94h		;Red
	out	dx,al		;

	shr	eax,4		;
	mov	dl,96h		;Green
	out	dx,al		;

	cmp	cl,10h		;�I���l ?
	jne	.loop2
	ret


BITS	16
;==============================================================================
;exit process for TOWNS on 16bit mode
;==============================================================================
proc32 exit_TOWNS_16
	cmp	b [load_nsdd], 0
	jz	short .no_nsdd
	;
	; [clear] real mode to 32bit mode far call routine
	;
	xor	bx, bx
	xor	dx, dx
	mov	ax, 0c207h
	int	8eh
.no_nsdd:
	;///////////////////////////////
	;reset key BIOS
	;///////////////////////////////
%if (INIT_KEY_BIOS)
	mov	ah,90h
	int	90h
	mov	ax,0501h
	int	90h
%endif

	ret

;******************************************************************************
; DATA
;******************************************************************************
segdata	data class=DATA align=4

global	load_nsdd

is_emulator	db	0
load_nsdd	db	1

;==============================================================================
;��CRTC ����e�[�u��
;==============================================================================
	align	4
TOWNS_CRTC_data:
	;// 24kHz���[�h 640�~400(4bits,FMR)+640�~400(4bits)
	dw	0040h, 0320h, 0000h, 0000h, 035fh, 0000h, 0010h, 0000h
	dw	036fh, 009ch, 031ch, 009ch, 031ch, 0040h, 0360h, 0040h
	dw	0360h, 0000h, 009ch, 0000h, 0050h, 0000h, 009ch, 0000h
	dw	0080h, 004ah, 0001h, 0000h, 803fh, 0003h, 0000h, 0188h

	;�p���b�g�f�[�^
TOWNS_PAL_layer0:	;�O���t�B�b�N��ʁi��O�j
	dw	0000h, 0008h, 0080h, 0088h, 0800h, 0808h, 0880h, 0888h
	dw	0777h, 000fh, 00f0h, 00ffh, 0f00h, 0f0fh, 0ff0h, 0fffh
TOWNS_PAL_layer1:	;�R���\�[�� (����) ���
	dw	0000h, 000bh, 00b0h, 00bbh, 0b00h, 0b0bh, 0bb0h, 0bbbh
	dw	0888h, 000fh, 00f0h, 00ffh, 0f00h, 0f0fh, 0ff0h, 0fffh

;==============================================================================
;��T-OS �̃������֘A�f�[�^
;==============================================================================
	align	4
T_OS_memory_map:
		;sel, base     ,  pages -1, type/level
	;dd	 3ch,        0,       0   , 0000h	;dummy
	dd	100h,0fffc0000h,  256/4 -1, 0a00h	;R/X : boot-ROM
	;dd	108h,0fffc0000h,  256/4 -1, 0000h	;R   : boot-ROM
	dd	120h, 80000000h,  512/4 -1, 0200h	;R/W : VRAM (16/32k)
	dd	128h, 80100000h,  512/4 -1, 0200h	;R/W : VRAM (256)
	dd	130h, 81000000h,  128/4 -1, 0200h	;R/W : Sprite-RAM
	dd	138h,0c2100000h,  264/4 -1, 0200h	;R/W : FONT-ROM,�w�KRAM
	dd	140h,0c2200000h,    4/4 -1, 0200h	;R/W : Wave-RAM
	dd	148h,0c2000000h,  512/4 -1, 0000h	;R   : OS-ROM
	;dd	11ch, 82000000h, 1024/4 -1, 0200h	;R/W : H-VRAM / 2 layer
	dd	11ch, 82000000h, 8704/4 -1, 0200h	;R/W : H-VRAM / 2 layer
	dd	124h, 83000000h, 1024/4 -1, 0200h	;R/W : H-VRAM / 1 layer
	dd	12ch, 84000000h, 1024/4 -1, 0200h	;R/W : VRAM??
	dd	0	;end of data
	;
	; "11ch" is separate VRAM mapped "0.0MB to 0.5MB" and "8.0MB to 8.5MB".
	; RUN386.EXE is mapped 16MB for "11ch, 124h, 12ch" selector.
	;
	align	4
T_OS_memory_map_386sx:
		;sel, base     ,  pages -1, type/level
	dd	100h, 00fc0000h,  256/4 -1, 0a00h	;R/X : boot-ROM
	;dd	108h, 00fc0000h,  256/4 -1, 0000h	;R   : boot-ROM
	dd	120h, 00a00000h,  512/4 -1, 0200h	;R/W : VRAM (16/32k)
	dd	128h, 00b00000h,  512/4 -1, 0200h	;R/W : VRAM (256)
	dd	130h, 00c00000h,  128/4 -1, 0200h	;R/W : Sprite-RAM
	dd	138h, 00f00000h,  264/4 -1, 0200h	;R/W : FONT-ROM,�w�KRAM
	dd	140h, 00f80000h,    4/4 -1, 0200h	;R/W : Wave-RAM
	dd	148h, 00e00000h,  512/4 -1, 0000h	;R   : OS-ROM
	dd	0	; Special thanks to @RyuTakegami

	align	4
T_OS_selector_alias:
		;ORG, alias, type/level
	dd	100h,  108h,  0000h	;boot-ROM
	dd	120h,  104h,  0200h	;VRAM (16/32k)
	dd	128h,  10ch,  0200h	;VRAM (256)
	dd	130h,  114h,  0200h	;Sprite-RAM

	dd	120h,   48h,  0200h	;�s���� alias / VRAM(16/32K)
	dd	120h,   1ch,  0200h	;�s���� alias / VRAM(16/32K)
	dd	0	;end of data
