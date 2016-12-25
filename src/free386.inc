;******************************************************************************
;■グローバルシンボル宣言
;******************************************************************************

	;--- for f386seg.asm ------------------------------
extern		GDT_adr, LDT_adr
extern		free_LINER_ADR
extern		free_RAM_padr
extern		free_RAM_pages
extern		DOS_mem_adr
extern		DOS_mem_pages
extern		page_dir

	;--- for f386cv86.asm -----------------------------
extern		to_PM_EIP, to_PM_data_ladr
extern		VCPI_entry
extern		v86_cs
extern		int_buf_adr
extern		int_buf_adr_org
extern		int_rwbuf_adr
extern		int_rwbuf_adr_org
extern		int_rwbuf_size
extern		VCPI_stack_adr
extern		heap_malloc, stack_malloc
extern		f386err

	;--- for int.asm ----------------------------------
;extern		int_buf_adr
extern		work_adr
extern		PM_stack_adr
extern		END_program
extern		IDT_adr
extern		RVects_flag_tbl
extern		DTA_off, DTA_seg
extern		DOS_int21h_adr
extern		top_adr
extern		default_API

extern		call_buf_adr
extern		call_buf_seg
extern		call_buf_ladr


