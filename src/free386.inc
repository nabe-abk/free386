;******************************************************************************
; extern variables
;******************************************************************************

;--- for selector.asm ------------------------------
extern		GDT_adr
extern		LDT_adr
extern		page_dir_ladr
extern		all_mem_pages

;--- for call_v86.asm -----------------------------
extern		to_PM_EIP
extern		to_PM_data_ladr
extern		VCPI_entry
extern		safe_stack_adr
extern		V86_cs

extern		use_vcpi
extern		LGDT_data
extern		LIDT_data
extern		RM_LIDT_data
extern		to_PM_LDTR
extern		to_PM_CR3

;--- for int.asm ----------------------------------
extern		IDT_adr
extern		PM_stack_adr
extern		RVects_flag_tbl
extern		DTA_off
extern		DTA_seg
extern		default_API
extern		pharlap_version

extern		call_buf_used
extern		call_buf_size
extern		call_buf_adr16
extern		call_buf_seg16
extern		call_buf_adr32

extern		user_cbuf_adr16
extern		user_cbuf_seg16
extern		user_cbuf_ladr

%ifdef USE_VCPI_8259A_API
extern		vcpi_8259m
extern		vcpi_8259s
%endif

;--- other ----------------------------------------
extern		error_exit_16
extern		exit_32
extern		error_exit_32

extern		top_ladr
extern		end_adr
extern		work_adr

; for pc_*.asm
extern		cpu_is_386sx
extern		msg_all_mem_type
extern		XMS_entry
extern		msg_xms_ver

