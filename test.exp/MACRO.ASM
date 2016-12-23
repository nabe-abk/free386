;******************************************************************************
;Å@ÇeÇíÇÖÇÖÇRÇWÇUÅ@ÅÉÉ}ÉNÉçïîÅÑ
;******************************************************************************
;
;
%imacro	PRINT	1
	mov	edx,%1
	mov	ah,09h
	int	21h
%endmacro

%imacro	PRINT_	1
	push	edx
	mov	edx,%1
	mov	ah,09h
	int	21h
	pop	edx
%endmacro

%imacro	PRINT_crlf	0
	mov	ah,02h
	mov	dl,13
	int	21h
	mov	dl,10
	int	21h
%endmacro

