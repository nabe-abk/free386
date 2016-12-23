;******************************************************************************
;Free386 APIサンプル
;				'ABK project' all left reserved. This is 'PDS'
;******************************************************************************
;
;　　2001/03/05　製作開始
;
;[TAB=8]

%include	"nasm_abk.h"	;NASM用ヘッダ
%include	"macro.asm"	;マクロ

code	segment para public 'CODE' use32
;******************************************************************************
;■コード
;******************************************************************************
..start:
	mov	ebx,'F386'	;Free386 funciton?
	mov	 ah,30h		;バージョン情報取得
	int	21h

	cmp	edx,' ABK'	;Free386 ?
	jne	no_free386

	mov	ah,10h		;API の初期化とロード
	int	9ch		;Free386 Funciton
	jc	fail

	;API コール
	mov	ah,08h		;function 番号
	int	9dh		;APIコール

	mov	ah,09h		;function 番号
	int	9dh		;APIコール

	mov	ah,4ch
	int	21h


	align	4
no_free386:
	PRINT	no_free386_mes
	mov	ah,4ch
	int	21h


	align	4
fail:
	PRINT	fail_mes
	mov	ah,4ch
	int	21h

	align	4
no_free386_mes:
	db 	'Free386 ではありません',13,10,'$'

	align	4
fail_mes:
	db 	'APIのロードに失敗しました',13,10,'$'

;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
	end
