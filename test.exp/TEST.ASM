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
	mov	edx,offset dir
	mov	ah,3ch
	int	21h

	int	0ffh



	;push any key MSG
	mov	edx,offset msg
	mov	ah,09h
	int	21h

	mov	ah,08h
	int	21h


	mov	ah,4ch
	xor	al,al
	int	21h


;------------------------------------------------------------------------------
;--- データ領域 ---------------------------------------------------------------

MSG	db	'This is test program',13,10
	db	'<<push any to exit>>',13,10,'$'

work	db	80h	dup(?)

dir	db	'd:\',0


xxx:

;------------------------------------------------------------------------------
shell	ends
	end	ENTRY		;入口番地の指定
