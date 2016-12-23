;******************************************************************************
;テストプログラム
;******************************************************************************
;
;		This is 'PDS'.
;
;[TAB=8]
shell	segment dword public 'CODE' use32
	assume	cs:shell,ds:shell

extrn	string_print:near
extrn	bin2deg_32:near
extrn	bin2hex_32:near

extrn	register_handler:near
extrn	free_handler:near

;------------------------------------------------------------------------------

_PC98_TIMER	equ	10h	;NEC PC9801 ｼﾘｰｽﾞ / EPSON互換機 :TIMER
_PC98_VSYNC	equ	11h	;NEC PC9801 ｼﾘｰｽﾞ / EPSON互換機 :VSYNC
_PC98_MOUSE	equ	14h	;NEC PC9801 ｼﾘｰｽﾞ / EPSON互換機 :MOUSE
_FM_TIMER	equ	20h	;Fujitsu FMR/FM-TOWNS ｼﾘｰｽﾞ / Panacom ｼﾘｰｽﾞ
_FMT_VSYNC	equ	21h	;Fujitsu FM-TOWNS ｼﾘｰｽﾞ         :VSYNC
_PCAT		equ	30h	;IBM PC/AT互換機(通称 DOS/V機)

;割り込みハンドラの登録
;	int	register_handler(int machin,int para,void *handler);
;	void	free_handler
;割り込み解除


;------------------------------------------------------------------------------
ENTRY:
	mov	edx,offset warning
	mov	ah,09h
	int	21h

	mov	ah,08h			;push any key
	int	21h


	mov	edx,offset cus_OFF	;カーソルOFF
	mov	ah,09h
	int	21h

	push	offset counter_handler
	push	0
	push	_FM_TIMER
	call	register_handler
	add	esp,8			;スタック除去

	align	4
count_loop:
	mov	eax,[count]
	mov	edi,offset NUM
	mov	ecx,8
	call	bin2deg_32

	mov	edx,offset MSG
	mov	ah,09h
	int	21h

	mov	ah,06h		;文字入力
	mov	dl,0ffh		;
	int	21h

	test	al,al		;入力あり?
	jz	count_loop


	mov	edx,offset cus_ON	;カーソルON
	mov	ah,09h
	int	21h

	call	free_handler	;割り込み解除

	mov	ah,4ch
	xor	al,al
	int	21h


	align	4	;割り込み
counter_handler:
	inc	dword ptr [count]
	ret


;------------------------------------------------------------------------------
;--- データ領域 ---------------------------------------------------------------

warning	db	'この binary は TOWNS 専用です。'
	db	'他機種では実行させないでください。 ',13,10
	db	'CTRL-C で強制終了します',13,10,'$'


cus_ON	db	27,'[0v$'
cus_OFF	db	27,'[1v$'

MSG	db	'Counter : '
NUM	db	'12345678',13,'$'

	align	4
count	dd	0


;------------------------------------------------------------------------------
shell	ends
	end	ENTRY		;入口番地の指定
