
extern	register_dump		;レジスタダンプ表示
extern	register_dump_fault	;レジスタダンプ for CPU Fault
extern	dump_err_code
extern	dump_orig_esp
extern	dump_orig_ss
extern	eax2hex			;eax to [edx]

%if INT_HOOK
extern	register_dump_from_int	;int用
%endif

	;routin made by kattyo@ABK
extern	searchpath		;パス検索

	;routin made by nabe@abk
extern	load_exp		;exp ファイルのロード
extern	run_exp			;exp の実行

