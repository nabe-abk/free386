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

;------------------------------------------------------------------------------
ENTRY:
	mov	eax,-1
	mov	ax,ds

	mov	edi,offset work
	mov	ecx,8
	call	bin2hex_32
	mov	dword ptr [edi],240a0dh

	mov	edx,offset work
	mov	ah,09h
	int	21h



	mov	ah,4ch
	xor	al,al
	int	21h


;------------------------------------------------------------------------------
;--- データ領域 ---------------------------------------------------------------

work	db	80h	dup(?)


;------------------------------------------------------------------------------
shell	ends
	end	ENTRY		;入口番地の指定
