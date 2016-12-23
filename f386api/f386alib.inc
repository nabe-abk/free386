;******************************************************************************
;Free386 API作成用ライブラリ
;		'ABK project' all right reserved. Copyright (C)nabe@abk
;******************************************************************************
;[TAB=8]

extrn	my_ds			;データセグメント
extrn	f386api_init		;初期化処理
extrn	f386api_return		;元プログラムへの復帰処理

public	func_table		;ジャンプテーブルオフセット

F386API_INT	equ	9dh	;Free386 API 用 int
