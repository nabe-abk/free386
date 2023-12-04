;******************************************************************************
; Free386 start
;******************************************************************************
;[TAB=8]
;
%include	"f386def.inc"

extern	start

global	show_title
global	verbose
global	search_PATH386
global	search_PATH
global	reset_CRTC
global	check_MACHINE
global	pool_for_paging
global	call_buf_sizeKB
global	resv_real_memKB

;==============================================================================
segment	text align=16 class=CODE use16
;==============================================================================
	times	100h	db 0		;ORG 100h の代わり
..start:
	jmp	near start

	;==================================================
	;動作定義変数 (パッチ用)
	;==================================================
	align	4

	;[+04 byte]
show_title	db	_show_title		;Free386 タイトル表示
verbose		db	_verbose		;冗長な表示モード
search_PATH386	db	_search_PATH386		;環境変数 PATH386 の検索
search_PATH	db	_search_PATH		;環境変数 PATH の検索

	;[+08 byte]
reset_CRTC	db	_reset_CRTC		;CRTC のリセット設定
check_MACHINE	db	_check_MACHINE		;簡易機種判別
		db	0
		db	0
	;[+12 byte]
pool_for_paging	db	_pool_for_paging	;ページング用の予約メモリ
call_buf_sizeKB	db	_call_buf_sizeKB	;CALL buffer size [KB]
resv_real_memKB	dw	_resv_real_memKB	;空けておくリアルメモリ [KB]

;==============================================================================
