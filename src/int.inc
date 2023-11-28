;******************************************************************************
;■グローバルシンボル宣言
;******************************************************************************

extern		PM_int_00h
extern		PM_int_dummy
extern		DOS_int_list
extern		intr_M0
extern		intr_S0
extern		int21h_table

extern		setup_F386_int

%if PRINT_TSUGARU
extern		int_21h_09h_output_tsugaru
%endif
