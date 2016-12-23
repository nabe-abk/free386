;******************************************************************************
;dump memory
;******************************************************************************
;
;		This is 'PDS'.
;
;[TAB=8]
shell	segment dword public 'CODE' use32
	assume	cs:shell,ds:shell

;------------------------------------------------------------------------------
ENTRY:
	; file create
	mov	edx,offset filename
	mov	ah,3ch
	xor	ecx,ecx		;cx=0
	int	21h

	; file open
	mov	edx,offset filename
	mov	ah,3dh
	mov	al,010b		;R/W mode
	int	21h
	; ax = handle
	mov	ebx, eax	; bx=handle

	push	ds
	mov	ax, 040h
	mov	ds, ax		; all mem selector
	xor	edx, edx	; start pointer
	mov	ecx, 0230000h	; 2.3MB
	mov	ah, 40h
	int	21h
	pop	ds

	; file close
	mov	ah, 3eh
	int	21h

	; program end
	mov	ah,4ch
	xor	al,al
	int	21h


;------------------------------------------------------------------------------
;--- データ領域 ---------------------------------------------------------------
filename	db	'dump.bin',0


;------------------------------------------------------------------------------
shell	ends
	end	ENTRY		;入口番地の指定
