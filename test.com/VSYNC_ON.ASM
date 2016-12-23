;
;VSYNC NOP for FM-TOWNS
;
; Original Copyright 1998 by kattyo.
; reversion 0.01 nabe@abk
;
; This is PSD.
;======================================

code	segment
;====================================== ;割り込みコード
	assume	cs:code,ds:code

	org	100h

start:
	mov	ax,cs
	mov	ds,ax

	in	al,12h
	and	al,11110111b
	out	12h,al

	mov	ah,4ch			;常駐終了
	int	21h

code	ends
	end	start
