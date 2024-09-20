
extern	register_dump
extern	register_dump_iret
extern	set_dump_head_is_fault

%if INT_HOOK
	extern	register_dump_from_int
	%if PRINT_TSUGARU && DUMP_DS_EDX
		extern	debug_dump_ds_edx
	%endif
%endif

extern	search_env
extern	search_path_env
extern	check_file_readable
extern	load_exp
extern	run_exp

extern	dump_orig_esp
extern	dump_orig_ss
