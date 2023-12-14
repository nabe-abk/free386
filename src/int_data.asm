;******************************************************************************
;　Free386　＜データ部＞
;******************************************************************************
;
segment	data align=4 class=CODE use16
group	comgroup text data
;/////////////////////////////////////////////////////////////////////////////
;★一般変数
;/////////////////////////////////////////////////////////////////////////////
	align	4
stack_pointer:
_esp	dd	0		;esp 保存用
_ss	dd	0		;ss

	;/// ハードウェア割り込み < 20h 時の退避領域 ///
%if Restore8259A
%if ((HW_INT_MASTER < 20h) || (HW_INT_SLAVE < 20h))
intr_table	resb	8*20h		;8 byte *20h
%endif
%endif


;/////////////////////////////////////////////////////////////////////////////
;★int 20h-2fh / DOS割り込みリスト（IDT設定用）
;/////////////////////////////////////////////////////////////////////////////
	align	4
DOS_int_list:
	;##### DOS 割り込み ###############################
	dw	offset	PM_int_20h
	dw	offset	PM_int_21h
	dw	offset	PM_int_22h
	dw	offset	PM_int_23h
	dw	offset	PM_int_24h
	dw	offset	PM_int_25h
	dw	offset	PM_int_26h
	dw	offset	PM_int_27h
	dw	offset	PM_int_28h
	dw	offset	PM_int_29h
	dw	offset	PM_int_2ah
	dw	offset	PM_int_2bh
	dw	offset	PM_int_2ch
	dw	offset	PM_int_2dh
	dw	offset	PM_int_2eh
	dw	offset	PM_int_2fh


;/////////////////////////////////////////////////////////////////////////////
;★int 21h / 割り込みテーブル（内部使用）
;/////////////////////////////////////////////////////////////////////////////
	align	4
int21h_table:
	;### function 00h-07h ######
	dd	offset int_21h_00h	;プログラム終了 ret = 0ffh
	dd	offset call_V86_int21	;エコー付きキー入力
	dd	offset call_V86_int21	;1文字標準出力
	dd	offset call_V86_int21	;1文字標準補助入力 (AUX)
	dd	offset call_V86_int21	;1文字標準補助出力 (AUX)
	dd	offset call_V86_int21	;1文字標準リスト出力 (PRN)
	dd	offset call_V86_int21	;直接標準入出力
	dd	offset call_V86_int21	;直接(フィルタなし)標準入力

	;### function 08h-0eh ######
	dd	offset call_V86_int21	;エコー無しキー入力
	dd	offset int_21h_09h	;文字列の出力
	dd	offset int_21h_0ah	;バッファ付き標準1行入力
	dd	offset call_V86_int21	;キーボードステータスチェック
	dd	offset call_V86_int21	;バッファクリア & 入力
	dd	offset call_V86_int21	;DISK reset (file buffer flash)
	dd	offset call_V86_int21	;カレントドライブの変更

	;### function 0fh-17h ######
%rep	(18h-0fh)
	dd	offset int_21h_notsupp	;FCB / サポートせず
%endrep

	;### function 18h-1fh ######
	dd	offset int_21h_unknown	;unkonwn
	dd	offset call_V86_int21	;カレントドライブ取得
	dd	offset int_21h_1ah	;ディスク転送アドレス設定(for 4eh,4fh)
	dd	offset int_21h_1bh	;カレントドライブのディスク情報取得
	dd	offset int_21h_1ch	;任意ドライブのディスク情報取得
	dd	offset int_21h_unknown	;unkonwn
	dd	offset int_21h_unknown	;unkonwn
	dd	offset int_21h_unknown	;unkonwn

	;### function 20h-27h ######
	dd	offset int_21h_unknown	;unkonwn
	dd	offset int_21h_notsupp	;FCB / サポートせず
	dd	offset int_21h_notsupp	;FCB
	dd	offset int_21h_notsupp	;FCB
	dd	offset int_21h_notsupp	;FCB
	dd	offset DOS_Extender_fn	;DOS-Extender ファンクション
	dd	offset int_21h_notsupp	;PSP作成 / サポートせず
	dd	offset int_21h_notsupp	;FCB

	;### function 28h-2fh ######
	dd	offset int_21h_notsupp	;FCB / サポートせず
	dd	offset int_21h_notsupp	;FCB
	dd	offset call_V86_int21	;日付取得
	dd	offset call_V86_int21	;日付設定
	dd	offset call_V86_int21	;時刻取得
	dd	offset call_V86_int21	;時刻設定
	dd	offset call_V86_int21	;ベリファイフラグの セット/リセット
	dd	offset int_21h_2fh	;ディスク転送アドレス取得(for 4eh,4fh)

	;### function 30h-37h ######
	dd	offset int_21h_30h	;Version 情報取得
	dd	offset int_21h_31h	;常駐終了
	dd	offset int_21h_notsupp	;DOS ディスクブロック入手
	dd	offset call_V86_int21	;CTRL-C 検出状態 設定／取得
	dd	offset int_21h_ret_esbx	;InDOSフラグのアドレス取得
	dd	offset DOS_Extender_fn	;DOS-Extender ファンクション
	dd	offset call_V86_int21	;ディスク残り容量取得
	dd	offset int_21h_unknown	;unknown

	;### function 38h-3fh ######
	dd	offset int_21h_38h	;国別情報の取得／設定
	dd	offset int_21h_ds_edx	;サブディレクトリの作成
	dd	offset int_21h_ds_edx	;サブディレクトリの削除
	dd	offset int_21h_ds_edx	;カレントディレクトリの変更
	dd	offset int_21h_ds_edx	;ファイル:作成
	dd	offset int_21h_ds_edx	;ファイル:オープン
	dd	offset call_V86_int21	;ファイル:クローズ
	dd	offset int_21h_3fh	;ファイル:読み込み

	;### function 40h-47h ######
	dd	offset int_21h_40h	;ファイル:書き込み
	dd	offset int_21h_ds_edx	;ファイル:削除
	dd	offset call_V86_int21	;ファイル:ポインタ移動
	dd	offset int_21h_ds_edx	;ファイル:属性の取得/設定
	dd	offset int_21h_44h	;IOCTRL
	dd	offset call_V86_int21	;ファイル:ハンドルの二重化
	dd	offset call_V86_int21	;ファイル:ハンドルの強制的な二重化
	dd	offset int_21h_47h	;カレントディレクトリの取得

	;### function 48h-4fh ######
	dd	offset int_21h_48h	;Pメモリ:LDTセグメント作成とメモリ確保
	dd	offset int_21h_49h	;Pメモリ:LDTセグメントとメモリの解放
	dd	offset int_21h_4ah	;Pメモリ:セグメントメモリ割り当て変更
	dd	offset int_21h_notsupp	;子プログラムの実行
	dd	offset int_21h_4ch	;プログラム終了
	dd	offset call_V86_int21	;子プログラムのリターンコード取得
	dd	offset int_21h_ds_edx	;最初に一致するファイルの検索
	dd	offset call_V86_int21	;次に一致するファイルの検索

	;### function 50h-57h ######
	dd	offset int_21h_unknown	;unknown
	dd	offset int_21h_unknown	;unknown
	dd	offset int_21h_ret_esbx	;先頭 MCB 取得 / IO.SYSワークアドレス取得
	dd	offset int_21h_unknown	;unknown
	dd	offset call_V86_int21	;ベリファイフラグの取得
	dd	offset int_21h_unknown	;unknown
	dd	offset int_21h_56h	;ファイルの移動（リネーム）
	dd	offset call_V86_int21	;ファイルの時間情報 取得/設定

	;### function 58h-5fh ######
	dd	offset call_V86_int21	;メモリ割り当て方法の変更
	dd	offset call_V86_int21	;拡張エラーコードの取得
	dd	offset int_21h_ds_edx	;テンプラリファイルの作成
	dd	offset int_21h_ds_edx	;新規ファイルの作成
	dd	offset call_V86_int21	;ファイルアクセスの ロック/アンロック
	dd	offset int_21h_unknown	;unknown
	dd	offset int_21h_notsupp	;MS-Networks 関連
	dd	offset int_21h_notsupp	;MS-Networks 関連

	;### function 60h-67h ######
	dd	offset int_21h_unknown	;unknown
	dd	offset int_21h_unknown	;unknown
	dd	offset int_21h_62h	;PSPセグメントを得る
	dd	offset int_21h_unknown	;unknown
	dd	offset int_21h_unknown	;unknown
	dd	offset int_21h_unknown	;unknown
	dd	offset int_21h_unknown	;unknown
	dd	offset call_V86_int21	;オープン可能な最大ハンドル数の設定

%rep	(int_21h_fn_MAX - 67h)
	dd	offset int_21h_unknown	;unknown
%endrep


;/////////////////////////////////////////////////////////////////////////////
;★DOS-Extender ファンクションテーブル / int 21h ax=25xxh
;/////////////////////////////////////////////////////////////////////////////
DOSExt_fn_table:
	;### function 00h-07h ######
	dd	offset DOSX_unknown	;(不明)
	dd	offset DOSX_fn_2501h	;CPUモード切り換え構造体のリセット
	dd	offset DOSX_fn_2502h	;プロテクトモード割り込みベクタの取得
	dd	offset DOSX_fn_2503h	;リアルモード割り込みベクタの取得
	dd	offset DOSX_fn_2504h	;プロテクトモード割り込みベクタの設定
	dd	offset DOSX_fn_2505h	;リアルモード割り込みベクタの設定
	dd	offset DOSX_fn_2506h	;常にプロテクトモードで動作する割り込み
	dd	offset DOSX_fn_2507h	;リアル/プロテクトの割り込みベクタ設定

	;### function 08h-0fh ######
	dd	offset DOSX_fn_2508h	;セレクタのベースリニアアドレス取得
	dd	offset DOSX_fn_2509h	;リニアアドレスから物理アドレスへの変換
	dd	offset DOSX_fn_250ah	;物理メモリのマッピング
	dd	offset DOSX_unknown	;(不明)
	dd	offset DOSX_fn_250ch	;ハードウェア割り込みのベクタ番号取得
	dd	offset DOSX_fn_250dh	;DOSメモリリンク情報の入手
	dd	offset DOSX_fn_250eh	;DOSルーチンのコール(no use セグメント)
	dd	offset DOSX_fn_250fh	;アドレスをDOSアドレスに変換

	;### function 10h-17h ######
	dd	offset DOSX_fn_2510h	;DOSルーチンのコール(far call)
	dd	offset DOSX_fn_2511h	;DOSルーチンのINTコール(int XXh)
	dd	offset DOSX_fn_2512h	;ディバクのためのプログラムロード
	dd	offset DOSX_fn_2513h	;セレクタのエイリアス作成
	dd	offset DOSX_fn_2514h	;セレクタの属性変更
	dd	offset DOSX_fn_2515h	;セレクタの属性取得
	dd	offset DOSX_unknown	;??
	dd	offset DOSX_fn_2517h	;DOS仲介バッファのアドレス取得


DOSExt_fn_table2:	;C0h～C3h
	;### function 18h-1fh ######
	dd	offset DOSX_fn_25c0h
	dd	offset DOSX_fn_25c1h
	dd	offset DOSX_fn_25c2h
	dd	offset int_21h_notsupp


;/////////////////////////////////////////////////////////////////////////////
;★Free386 function table
;/////////////////////////////////////////////////////////////////////////////
F386fn_table:
	;### function 00h-07h ######
	dd	offset F386fn_00h
	dd	offset F386fn_01h
	dd	offset F386fn_02h
	dd	offset F386fn_03h
	dd	offset F386fn_04h
	dd	offset F386fn_05h
	dd	offset F386fn_06h
	dd	offset F386fn_07h

	;### function 08h-0fh ######
	dd	offset F386fn_08h
	dd	offset F386fn_09h
	dd	offset F386fn_0ah
	dd	offset F386fn_0bh
	dd	offset F386fn_0ch
	dd	offset F386fn_0dh
	dd	offset F386fn_0eh
	dd	offset F386fn_0fh

	;### function 10h-17h ######
	dd	offset F386fn_10h
	dd	offset F386fn_11h
	dd	offset F386fn_12h
	dd	offset F386fn_13h
	dd	offset F386fn_14h
	dd	offset F386fn_15h
	dd	offset F386fn_16h
	dd	offset F386fn_17h

%rep	(F386_INT_fn_MAX - 17h)
	dd	offset F386fn_unknown	;ダミー
%endrep
