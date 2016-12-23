;
;
;nasm -f bin coco.asm -o coco.com
;
;-----------------------------------------------------------------------------
;segment	.text align=16 class=CODE use16
;-----------------------------------------------------------------------------
;	times	100h	db 0		;ORG 100h ‚Ì‘ã‚í‚è
	org	100h
;..start:

	mov	bp, 0
	mov	di, data

	align	4
lp0:
	mov	cx, bp
	mov	ax, 0c103h
	int	8eh

	inc	bp
	add	di, 10h
	test	ah, ah
	jz	lp0

	mov	ax,4c00h
	int	21h

;-----------------------------------------------------------------------------
	align	100h
data:
	times	100h	db -1

