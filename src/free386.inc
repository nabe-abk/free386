;******************************************************************************
; extern variables
;******************************************************************************

;--- for f386seg.asm ------------------------------
extern		GDT_adr
extern		LDT_adr
extern		IDT_adr
extern		page_dir_ladr
extern		free_liner_adr
extern		free_RAM_padr
extern		free_RAM_pages

;--- for f386cv86.asm -----------------------------
extern		to_PM_EIP
extern		to_PM_data_ladr
extern		VCPI_entry
extern		VCPI_stack_adr
extern		V86_cs
extern		f386err

;--- for int.asm ----------------------------------
extern		IDT_adr
extern		PM_stack_adr
extern		RVects_flag_tbl
extern		DTA_off
extern		DTA_seg
extern		DOS_int21h_adr
extern		default_API
extern		pharlap_version

extern		call_buf_used
extern		call_buf_size
extern		call_buf_adr16
extern		call_buf_seg16
extern		call_buf_adr32

;--- other ----------------------------------------
extern		error_exit_16
extern		exit_32
extern		error_exit_32

extern		top_ladr
extern		end_adr
extern		work_adr
