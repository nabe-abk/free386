;*************************************************
;　V86 ←→ Protect 低レベル連携ルーチン / Free386
;*************************************************

extern	setup_cv86		;call v86 の初期設定
extern	clear_mode_data		;モード切替えデータの初期化

extern	call_V86_int		;int 呼び出し
extern	call_V86_int21		;int 21h 呼び出し

extern	call_V86		;汎用的なな呼び出しルーチン (call して使用)
extern	rint_labels_adr		;リアルモード割り込みフックルーチン先頭アドレス

extern	call_v86_ds
extern	call_v86_es
extern	ISTK_nest

