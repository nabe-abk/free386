
extern	make_selector		;386形式メモリセレクタ作成
extern	make_selector_4k		;386形式メモリセレクタ作成 (4KB 単位)
extern	set_physical_mem	;物理メモリを指定リニアアドレスに配置する
extern	alloc_DOS_mem		;DOSメモリを貼り付け
extern	alloc_RAM		;RAM をリニアアドレスに配置する
extern	alloc_RAM_with_ladr	;RAM を指定のリニアアドレスに配置する

extern	map_memory		;テーブルを読み出し、物理メモリをセレクタに配置
extern	make_aliases		;セレクタのエイリアスを作成する（テーブル参照）
extern	make_alias		;エイリアスを作成する

extern	get_maxalloc		;最大割り当て可能メモリ(page)取得
extern	get_maxalloc_with_adr	;最大割り当て可能メモリ(page)取得
extern	get_selector_last	;セレクタ最後尾リニアアドレス(+1)取得

extern	sel2adr			;セレクタ値 to アドレス変換
extern	search_free_LDTsel	;空きLDTセレクタの検索
extern	selector_reload		;全データセレクタのリロード
