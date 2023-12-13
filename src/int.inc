;******************************************************************************
;■グローバルシンボル宣言
;******************************************************************************

extern		PM_int_00h
extern		PM_int_dummy
extern		DOS_int_list
extern		int21h_table

extern		setup_F386_int

extern		HW_INT_TABLE_M
extern		HW_INT_TABLE_S


%if PRINT_TSUGARU
	extern	int_21h_09h_output_tsugaru
%endif
