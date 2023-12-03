;*************************************************
;　V86 ←→ Protect 低レベル連携ルーチン / Free386
;*************************************************

extern	setup_cv86		;call V86 の初期設定
extern	clear_mode_data		;モード切替えデータの初期化

extern	call_V86_int		;int 呼び出し
extern	call_V86_int21		;int 21h 呼び出し
extern	call_V86_HARD_int	;call hardware interrupt

extern	call_V86		;汎用的なな呼び出しルーチン (call して使用)
extern	call_V86_ds
extern	call_V86_es

extern	callf32_from_V86

extern	alloc_SW_stack_32
extern	free_SW_stack_32
extern	rint_labels_adr

