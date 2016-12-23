;
;システム関連定義用インクルードファイル（アセンブラ用）
;
;1998/02/24
;1998/03/24
;
;[TAB=8]
;/////　割り込み定義 //////////////////////////////////////////////////////////

;リアルモード仲介ドライバで使用する割り込み

Interrupt_No		equ	0e2h	;プログラム使用 Int 番号
Int_NO_str_H		equ	'e'	;メッセージ表示用　２ケタ目
Int_NO_str_L		equ	'2'	;　　　　　　　　　１ケタ目

kernel_call_int		equ	0e3h	;カーネルコールに使用 Int 番号

kernel_call	macro
	int	kernel_call_int
	endm


;/////　以下セグメント定義 ////////////////////////////////////////////////////
;
;	現在は拡張したＬＤＴの、0f04h～0ffch を使用しています。
;

LDT_limit		equ	0fffh	;リミット値：新LDTサイズ＝4KB

;ここのかたまりは実際には即値で書いてるけど……(^^;;
NULL_SEL		equ	0000h	;ヌルセレクタ
LDT_SEL 		equ	0028h	;ＬＤＴにロードされるセレクタ
LDT_access_SEL		equ	0030h	;ＬＤＴアクセスに用いるセレクタ
GDT_access_SEL		equ	0038h	;ＧＤＴアクセスに用いるセレクタ
IDT_access_SEL		equ	0050h	;ＩＤＴアクセスに用いるセレクタ

DOS_MEM_SEL		equ	0034h	;DOSﾒﾓﾘ(1MB以下)にｱｸｾｽに使用するｾﾚｸﾀ

KERNEL_CS		equ	000ch	;カーネルのコードセグメントセレクタ
KERNEL_DS		equ	0014h	;カーネルのデータセグメントセレクタ

;----------------------------------------------------------------------------

TSS_access		equ	0e04h	;TSS ｱｸｾｽ用ｾﾚｸﾀ
IOPL_adress 		equ	1000h	; TSS内 IOPL アドレス



