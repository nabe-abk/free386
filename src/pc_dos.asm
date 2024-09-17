;******************************************************************************
;Å@Free386 - for DOS general purpose
;******************************************************************************
; this code for DOS general purpose with non VCPI enviroment
;
seg16	text class=CODE align=4 use16
;==============================================================================
; check machine  TOWNS, PC-98, PC-AT
;==============================================================================
proc2	get_8259a_vector
	;---------------------------------------------------
	;FM TOWNS
	;---------------------------------------------------
	call	check_TOWNS
	jc	.not_TOWNS

	mov	bx, 40h		; HW mastar int
	mov	cx, 48h		; HW slave  int
	;clc	;cleared
	ret
.not_TOWNS:

	;---------------------------------------------------
	;PC-98x1
	;---------------------------------------------------
	call	check_PC98
	jc	.not_PC98

	mov	bx, 08h		; HW mastar int
	mov	cx, 10h		; HW slave  int
	;clc	;cleared
	ret
.not_PC98:

	;---------------------------------------------------
	;PC/AT
	;---------------------------------------------------
	call	check_AT
	jc	.not_AT

	mov	bx, 08h		; HW mastar int
	mov	cx, 70h		; HW slave  int
	;clc	;cleared
	ret

.not_AT:
	stc
	ret

;------------------------------------------------------------------------------
; check routine
;------------------------------------------------------------------------------
check_TOWNS:
	in	al, 30h		;CPU register
	cmp	al, 0ffh
	jz	.not_fm		;0ffh is not FM series

	mov	dx,020eh	;Drive switch register
	in	al,dx		;
	and	al,0feh		;
	jnz	.not_TOWNS	;all 0 is TOWNS
	clc
	ret
.not_fm:
.not_TOWNS:
	stc
	ret


	align	2
check_PC98:
	in	al,90h		;FD I/O
	add	al, 1		;cy = al is 0ffh
	jc	.ret

	in	al,94h		;FD I/O
	add	al, 1		;cy = al is 0ffh
.ret: 	ret


	align	2
check_AT:
	in	al,0D0h		;DMA Status Register
	add	al, 1		;cy = al is 0ffh
	jc	.ret

	in	al,0DAh		;DMS I/O
	add	al, 1		;cy = al is 0ffh
.ret:	ret
