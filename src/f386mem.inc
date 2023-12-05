;*************************************************
; f386mem.inc
;*************************************************

extern	heap_malloc
extern	heap_calloc
extern	stack_malloc
extern	stack_calloc

extern	init_dos_malloc
extern	dos_malloc_page

extern	  get_gp_buffer_32
extern	 free_gp_buffer_32
extern	clear_gp_buffer_32
extern	  get_gp_buffer_16
extern	 free_gp_buffer_16

extern	alloc_sw_stack_32
extern	 free_sw_stack_32
extern	clear_sw_stack_32

extern	free_heap_top
extern	free_heap_bottom
extern	DOS_mem_ladr
extern	DOS_mem_pages
extern	DOS_alloc_sizep		; use only memory information
extern	DOS_alloc_seg		; use only memory information

extern	gp_buffer_remain
extern	gp_buffer_table
extern	sw_stack_bottom
extern	sw_stack_bottom_orig


