
extern	make_selector
extern	make_selector_4k
extern	set_physical_mem
extern	alloc_DOS_mem
extern	alloc_RAM
extern	alloc_RAM_with_ladr

extern	map_memory		;物理メモリを配置しセレクタを作成、テーブル参照
extern	make_aliases		;セレクタのエイリアスを作成（テーブル参照）
extern	make_alias		;セレクタのエイリアスを作成
extern	get_maxalloc		;最大割り当て可能メモリ(page)取得
extern	get_maxalloc_with_adr	;最大割り当て可能メモリ(page)取得
extern	get_selector_last	;セレクタ最後尾リニアアドレス(+1)取得
extern	sel2adr			;セレクタ値 to アドレス変換
extern	search_free_LDTsel	;空きLDTセレクタの検索
extern	selector_reload		;全データセレクタのリロード

extern	regist_managed_LDTsel	;regist to managed LDT selector
extern	remove_managed_LDTsel	;remove from managed LDT selector
extern	update_free_linear_adr	;update to create new selector
