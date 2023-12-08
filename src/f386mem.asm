;******************************************************************************
; Free386 memory functions
;******************************************************************************
;[TAB=8]
;
%include	"macro.inc"
%include	"f386def.inc"

%include	"start.inc"
%include	"free386.inc"

segment	text align=4 class=CODE use16
;******************************************************************************
; heap memory functions
;******************************************************************************
;	in	ax = size (byte). recommended in multiples of 16.
;		cl = error code (for allocation failure)
;	out	di = offset
;
proc heap_malloc
	mov	di,[free_heap_top]	;上位空きメモリ割り当て
	add	[free_heap_top],ax	;サイズ分加算
	jc	heap_alloc_error
	jmp	short check_heap_mem

	align	4
proc stack_malloc			;下位からのメモリ割り当て
	mov	di,[free_heap_bottom]	;最下位空きメモリ
	sub	[free_heap_bottom],ax	;新たな値を記録
	; jmp	short check_heap_mem

check_heap_mem:
	push	ax
	push	bx
	mov	ax,[free_heap_top]
	mov	bx,[free_heap_bottom]
	dec	ax
	dec	bx
	cmp	ax,bx
	pop	bx
	pop	ax
	ja	heap_alloc_error
	ret
heap_alloc_error:
	mov	ah, cl			;error code
	jmp	error_exit_16

;------------------------------------------------------------------------------
; heap memory functions with zero fill
;------------------------------------------------------------------------------
proc heap_calloc
	push	w (mem_clear)		;戻りラベル
	jmp	heap_malloc

	align	4
proc stack_calloc
	std
	push	w (mem_clear)		;戻りラベル
	jmp	stack_malloc

	align	4
mem_clear:		;メモリの 0 クリア
	push	eax
	push	ecx
	push	edi

	movzx	ecx,ax			;ecx メモリサイズ
	movzx	edi,di			;edi 書き込み先
	xor	eax,eax			;eax = 0
	shr	ecx,2			;4 で割る
	rep	stosd			;メモリ塗りつぶし ->es:[edi]

	pop	edi
	pop	ecx
	pop	eax
	ret

;******************************************************************************
; DOS memory functions
;******************************************************************************
;------------------------------------------------------------------------------
;alloc memory from DOS
;------------------------------------------------------------------------------
proc init_dos_malloc
	xor	eax, eax
	xor	ebx, ebx

	mov	ah, 48h
	mov	bx, 0ffffh
	int	21h
	cmp	ax,08h
	jne	.not_alloc

	mov	ax, [resv_real_memKB]
	shl	ax, 10 - 4		; KB to paragrah
	cmp	bx, ax			; free memory < reserved memory
	jbe	.not_alloc		; jmp

	sub	bx, ax			; bx = can use memory(para)
	dec	bx			; for MCB (1para)
	jz	.not_alloc

	mov	ah, 48h
	int	21h
	jc	.not_alloc

	mov	[DOS_alloc_seg],  ax	;allocate DOS memory segment
	mov	[DOS_alloc_sizep],bx	;allocate DOS memory size(para)
	mov	bp, bx

	mov	dx, ax
	add	ax, 000ffh		;for 4KB fragment
	and	ax, 0ff00h		;mask
	mov	cx, ax			;cx = original seg
	sub	cx, dx			;cx = top frag paras
	sub	bx, cx			;bx = size - frag size

	shl	eax, 4			;para to linear address
	mov	[DOS_mem_ladr], eax	;save

	mov	cx, bx
	and	bx, 0ff00h		;4KB unit
	sub	cx, bx			;cx = bottom frag paras
	mov	dx, cx			;dx = save
	shr	ebx, 12 - 4		;para to page
	mov	[DOS_mem_pages],ebx	;save

	test	cx, cx
	jz	.skip_shrink

	sub	bp, cx			;bp = new para size
	mov	bx, bp			;bx = new para size

	push	es
	mov	es, [DOS_alloc_seg]
	mov	ah, 4ah
	int	21h			;Shrink memory block
	pop	es
	jc	.skip

	mov	[DOS_alloc_sizep],bx	;new dos memory size(para)
	shr	dx, 10 - 4		;para to KB
	add	b [resv_real_memKB],dl	;Reserved memory increase

.skip:
.skip_shrink:
.not_alloc:
	ret

;------------------------------------------------------------------------------
;alloc DOS memory page
;------------------------------------------------------------------------------
;	in	 ax = page
;		 cl = error code (for allocation failure)
;	out	edi = liner address
;
proc dos_malloc_page
	cmp	[DOS_mem_pages], ax
	jb	.error

	push	ebx
	sub	[DOS_mem_pages], ax
	movzx	ebx, ax
	shl	ebx, 12		; page to byte

	mov	eax, [DOS_mem_ladr]
	add	[DOS_mem_ladr], ebx
	pop	ebx
	ret

.error:
	mov	ah, cl
	jmp	error_exit_16



;******************************************************************************
; General purpose buffer function
;******************************************************************************
BITS	32
;==============================================================================
; Get general purpose buffer
;==============================================================================
; out	eax = buffer pointer, 0 is failed
;
proc get_gp_buffer_32
	pushfd
	push	ebx
	push	ecx
	push	ds

	mov	cx, F386_ds
	mov	ds, cx

	cli
	mov	eax, [gp_buffer_remain]
	test	eax, eax
	jz	.fail

	dec	eax
	mov	[gp_buffer_remain], eax

	mov	eax, 80000000h
	mov	ebx, [gp_buffer_used]
	xor	ecx, ecx
.loop:
	inc	ecx
	cmp	cl, 32
	jz	short .fail
	rol	eax, 1
	test	ebx, eax
	jnz	short .loop

	or	ebx, eax
	mov	[gp_buffer_used], ebx	; set used flag

	mov	eax, [gp_buffer_table -4 + ecx*4]
.ret:
	pop	ds
	pop	ecx
	pop	ebx
	popfd
	ret
.fail:
	xor	eax, eax
	jmp	short .ret

;==============================================================================
; free general purpose buffer
;==============================================================================
; in	eax = buffer pointer
; out	eax = 0 success
;	    = 1 failed
;
proc free_gp_buffer_32
	pushfd
	push	ebx
	push	ecx
	push	ds

	mov	cx, F386_ds
	mov	ds, cx

	mov	ebx, gp_buffer_table
	xor	ecx, ecx
.loop:
	cmp	[ebx], eax
	je	.found
	add	ebx, 4
	inc	ecx
	cmp	cl, GP_BUFFERS
	jb	.loop
	jmp	.fail

.found:
	mov	ebx, [gp_buffer_used]
	btc	ebx, ecx	; cy <- ecx bit and ecx bit revers
	jnc	.fail		; used flag not set

	mov	[gp_buffer_used], ebx
	inc	d [gp_buffer_remain]

	xor	eax, eax
.ret:
	pop	ds
	pop	ecx
	pop	ebx
	popfd
	ret

.fail:
	mov	eax, 1
	jmp	short .ret


;==============================================================================
; clear general purpose buffer
;==============================================================================
proc clear_gp_buffer_32
	mov	d [gp_buffer_used],   0
	mov	d [gp_buffer_remain], GP_BUFFERS
	ret


BITS	16
;==============================================================================
; Get general purpose buffer (16bits)
;==============================================================================
; out	ax = buffer pointer, 0 is failed
;
proc get_gp_buffer_16
	pushf
	push	ebx
	push	ecx

	cli
	mov	ax, [gp_buffer_remain]
	test	ax, ax
	jz	.fail

	dec	ax
	mov	[gp_buffer_remain], ax

	mov	eax, 80000000h
	mov	ebx, [gp_buffer_used]
	xor	ecx, ecx
.loop:
	inc	cx
	cmp	cl, 32
	jz	short .fail
	rol	eax, 1
	test	ebx, eax
	jnz	short .loop

	or	ebx, eax
	mov	[gp_buffer_used], ebx	; set used flag

	mov	ax, [gp_buffer_table -4 + ecx*4]
.ret:
	pop	ecx
	pop	ebx
	popf
	ret
.fail:
	xor	ax, ax
	jmp	short .ret

;==============================================================================
; free general purpose buffer (16bits)
;==============================================================================
; in	ax = buffer pointer
; out	ax = 0 success
;	   = 1 failed
;
proc free_gp_buffer_16
	pushf
	push	ebx
	push	ecx

	mov	bx, gp_buffer_table
	xor	ecx, ecx
.loop:
	cmp	[bx], ax
	je	.found
	add	bx, 4
	inc	cx
	cmp	cl, GP_BUFFERS
	jb	.loop
	jmp	.fail

.found:
	mov	ebx, [gp_buffer_used]
	btc	ebx, ecx	; cy <- ecx bit and ecx bit revers
	jnc	.fail		; used flag not set

	mov	[gp_buffer_used], ebx
	inc	w [gp_buffer_remain]

	xor	ax, ax
.ret:
	pop	ecx
	pop	ebx
	popf
	ret

.fail:
	mov	ax, 1
	jmp	short .ret

;******************************************************************************
; switch cpu mode stack allocation
;******************************************************************************
BITS	32
;==============================================================================
; allocation from heap
;==============================================================================
; in	-
; out	eax	new stack pointer
;
proc alloc_sw_stack_32
	pushfd

	cli
	cmp	b [sw_cpumode_nest], SW_max_nest
	jae	short .error
	inc	b [sw_cpumode_nest]

	mov	eax, [sw_stack_bottom]
	sub	d [sw_stack_bottom], SW_stack_size

	popfd
	ret

.error:
	mov	ah, 14
	jmp	error_exit_32

;==============================================================================
; free SW stack memory
;==============================================================================
;
proc free_sw_stack_32
	pushfd
	push	eax

	cli
	cmp	b [sw_cpumode_nest], 0
	je	short .error
	dec	b [sw_cpumode_nest]

	add	d [sw_stack_bottom], SW_stack_size

	pop	eax
	popfd
	ret

.error:
	mov	ah, 15
	jmp	error_exit_32

;==============================================================================
; clear SW stack
;==============================================================================
proc clear_sw_stack_32
	push	eax
	mov	eax, [sw_stack_bottom_orig]
	mov	[sw_stack_bottom], eax

	mov	b [sw_cpumode_nest], 0
	pop	eax
	ret


;******************************************************************************
; DATA
;******************************************************************************
segment	data align=4 class=CODE use16
group	comgroup text data

global	free_heap_top
global	free_heap_bottom
global	DOS_mem_ladr
global	DOS_mem_pages
global	DOS_alloc_sizep		; use only memory information
global	DOS_alloc_seg		; use only memory information

global	gp_buffer_remain
global	gp_buffer_table
global	sw_stack_bottom
global	sw_stack_bottom_orig

free_heap_top		dd	offset end_adr	; heap memory top    offset
free_heap_bottom	dd	10000h & 0ffffh	; heap memory bottom offset+1

DOS_alloc_seg		dd	0		;allocate DOS memory segment
DOS_alloc_sizep		dd	0		;allocate DOS memory size(para)
DOS_mem_ladr		dd	0		;can use DOS memory linear address
DOS_mem_pages		dd	0		;can use DOS memory pages

gp_buffer_remain	dd	GP_BUFFERS	; remain buffers
gp_buffer_used		dd	0		; buffer used flag
gp_buffer_table:
  times	GP_BUFFERS	dd	0		; address

sw_cpumode_nest		dd	0		; Switch cpu mode nest counter
sw_stack_bottom		dd	0		; stack pointer
sw_stack_bottom_orig	dd	0		; original value for reset (AX=2501h)

;******************************************************************************
