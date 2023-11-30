;
;動作定義内部変数
;

extern	show_TITLE		;タイトル表示
extern	verbose			;冗長な表示
extern	search_PATH386		;"PATH386" の検索
extern	search_PATH		;"PATH" の検索

extern	reset_CRTC		;CRTC の初期化
extern	check_MACHINE		;機種判別

extern	pool_for_paging		;ページング用の予約メモリ
extern	callbuf_sizeKB		;CALL buffer size (KB)
extern	real_mem_pages		;プログラム実行用リアルメモリ
extern	maximum_heap		;ヘッダを無視して最大ヒープメモリを割当
