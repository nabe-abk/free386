;******************************************************************************
;■グローバルシンボル宣言
;******************************************************************************

extern		PM_int_00h
extern		PM_int_dummy
extern		HW_int_master_table
extern		HW_int_slave_table

extern		setup_F386_int

extern		DOS_int_list
extern		int21h_table

%if PRINT_TSUGARU
	extern	int_21h_09h_output_tsugaru
%endif
