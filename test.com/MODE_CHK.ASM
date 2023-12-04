;
;CPU mode checker
;
; nasm -f bin mode_chk.asm -o mode_chk.com
;
;[TAB=8]
;------------------------------------------------------------------------------
%macro	PRINT	1
	mov	edx,%1
	mov	ah,09h
	int	21h
%endmacro

;------------------------------------------------------------------------------
	org	100h
start:
	PRINT	iopl

	pushf
	pop	ax
	shr	ax,12		;IOPL is lower bits
	and	al,3		;IOPL mask
	add	al,'0'
	int	29h

	PRINT	cr_lf


check_V86:
	mov	dx, rm
	mov	eax,cr0
	test	ax,1	;PE ビットをテスト
	jz	short check_paging

	mov	dx, pm
.skip:
	mov	ah,09h
	int	21h


check_paging:
	PRINT	paging

	mov	eax, cr0
	test	eax, 80000000h
	mov	dx, _on
	jnz	.skip
	mov	dx, _off
.skip:
	mov	ah,09h
	int	21h


	; end
	mov	ah,4Ch
	xor	al,al
	int	21h

;------------------------------------------------------------------------------
pm	db	'Virtual 86 Mode',13,10,'$'
rm	db	'Real Mode',13,10,'$'

iopl	db	'IOPL = $'
s	db	'0123'
cr_lf	db	13,10,'$'

paging	db	'paging = $'
_on	db	'on ',13,10,'$'
_off	db	'off',13,10,'$'

