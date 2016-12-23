;******************************************************************************
;■グローバルシンボル宣言
;******************************************************************************

extern		PM_int_00h
extern		PM_int_dummy
extern		DOS_int_list

%if (enable_INTR)
extern		intr_M0
extern		intr_S0
%endif

extern		setup_F386_int
