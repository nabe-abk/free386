;
;READ T-BIOS / This is PSD.
;
;	Thanks to Mamiya (san).
;
;
.386
;======================================
code	segment use16
;====================================== ;割り込みコード
	assume	cs:code,ds:code

	org	100h

start:
	mov	dx,3b90h
	call	CMOS_READ
	mov	esi,ebx

	mov	dx,3b98h
	call	CMOS_READ
	mov	edi,ebx

	mov	dx,3ad0h
	call	CMOS_READ

	mov	ah,4ch			;常駐終了
	int	21h


	align	2
CMOS_READ:
	add	dx,6
	in	al,dx
	mov	bh,al
	sub	dx,2

	in	al,dx
	mov	bl,al
	sub	dx,2

	shl	ebx,16

	in	al,dx
	mov	bh,al
	sub	dx,2

	in	al,dx
	mov	bl,al
	ret

code	ends




	end	start
