;******************************************************************************
;　Ｆｒｅｅ３８６　＜プログラム先頭＞
;******************************************************************************
;[TAB=8]
;
%include	"f386def.inc"		;定数部の挿入

extern	start

global	title_disp, verbose
global	see_PATH386, see_PATH
global	reset_CRTC, check_MACHINE
global	pool_for_paging
global	callbuf_sizeKB
global	real_mem_pages
global	maximum_heap

;----------------------------------------------------------------------------
segment	text align=16 class=CODE use16
;-----------------------------------------------------------------------------
	times	100h	db 0		;ORG 100h の代わり
..start:
	jmp	start

	;==================================================
	;動作定義変数 (パッチ用)
	;==================================================
	align	4

	;[+04 byte]
title_disp	db	_TITLE_disp	;Free386 タイトル表示
verbose		db	_Verbose	;冗長な表示モード
see_PATH386	db	_see_PATH386	;環境変数 PATH386 の検索
see_PATH	db	_see_PATH	;環境変数 PATH の検索

	;[+08 byte]
reset_CRTC	db	_reset_CRTC	;CRTC のリセット設定
check_MACHINE	db	_check_MACHINE	;簡易機種判別
		db	0
		db	0
	;[+12 byte]
pool_for_paging	db	_POOL_for_paging;ページング用の予約メモリ
callbuf_sizeKB	db	_CALLBUF_sizeKB	;CALL buffer size (KB)
real_mem_pages	db	_REAL_mem_pages	;プログラム実行用リアルメモリ
maximum_heap	db	0		;ヘッダを無視して最大ヒープメモリを割り当て

	;--------------------------------------------------

	align	16
	;==================================================
	;ディバグのための領域
	;==================================================
	;resb	2000h - 17a0h		;for DEBUG


;-----------------------------------------------------------------------------
