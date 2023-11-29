;
;16 bit ルーチン
;
extern	get_parameter
extern	HEX_conv4
extern	HEX_conv2

;
;32 bit ルーチン
;
extern	string_print
extern	bin2deg_32
extern	bin2hex_32
extern	rewrite_next_hash_to_hex
extern	rewrite_next_hash_to_deg

;
;データ部
;
extern	paras			;発見したパラメーターの数
extern	paras_last		;パラメタ列最後尾
extern	paras_p			;パラメタ先頭へのポインタ


