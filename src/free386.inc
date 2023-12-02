;******************************************************************************
; extern variables
;******************************************************************************

extern		GDT_adr, LDT_adr
extern		free_LINER_ADR
extern		free_RAM_padr
extern		free_RAM_pages
extern		DOS_mem_adr
extern		DOS_mem_pages
extern		page_dir

extern		to_PM_EIP, to_PM_data_ladr
extern		VCPI_entry
extern		VCPI_stack_adr
extern		v86_cs
extern		f386err

extern		PM_stack_adr
extern		END_program
extern		IDT_adr
extern		RVects_flag_tbl
extern		DTA_off, DTA_seg
extern		DOS_int21h_adr
extern		default_API
extern		pharlap_version

extern		program_err_end
extern		end_adr

extern		top_adr
extern		work_adr

extern		call_buf_used
extern		call_buf_size
extern		call_buf_adr16
extern		call_buf_seg16
extern		call_buf_adr32

