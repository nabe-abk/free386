;******************************************************************************
; Free386 chcker
;******************************************************************************
;
;[TAB=8]
;------------------------------------------------------------------------------
%macro	PRINT	1
	mov	edx,%1
	mov	ah,09h
	int	21h
%endmacro
;------------------------------------------------------------------------------
start:
	mov	ah ,30h
	mov	ebx,'F386'
	int	21h
	cmp	edx,' ABK'
	jne	not_f386

	PRINT	msg_is_f386
	int	0ffh
	jmp	end

not_f386:
	PRINT	msg_not_f386

end:
	mov	ah,4ch
	xor	al,al
	int	21h




msg_is_f386	db	'DOS-Extender is Free386!',13,10
		db	'Do register dump by Free386 int 0ffh function.',13,10,13,10,'$'
msg_not_f386	db	'DOS-Extender is not Free386!',13,10,'$'

