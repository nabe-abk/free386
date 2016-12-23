;******************************************************************************
;　マルチタスク　サポート　ライブラリ
;******************************************************************************
;
; ★セグメント・メモリ部門
;
;　　1997/12/29　製作開始
;　　1998/01/18　make_new_ldt作成
;　　1998/03/21　ファイル分離
;
;
;		'ABK project' all right reserved. Copyright (C)nabe@abk
;
;[TAB=8]

	.386p
code	segment dword public 'CODE' use32
	assume	cs:code,ds:code
code	ends

data	segment dword public 'DATA' use32
data	ends

include		system.inc	;システム定義ﾌｧｲﾙ ロード（ｾﾚｸﾀ値･割り込み等）

	public	make_segment,free_segment
	public	get_dt,get_limit,get_linear_offset
	public	linear_to_physical,get_physical_address
	public	make_new_ldt,make_mems
	public	make_tss,make_gate
	public	store_tr,load_tr,load_cs,load_ds,load_far_mem

code	segment
;******************************************************************************
;■コード
;******************************************************************************
;
;------------------------------------------------------------------------------
;●新規セグメント作成
;------------------------------------------------------------------------------
;int make_selector(int page)
;	page　＝割り当てるページ(4Kbyte単位)数
;
;	戻り値　0～0fff8h＝正常終了（LDTの新セグメントセレクタ）
;		0ffffh～ ＝異常終了（メモリ/セレクタ不足）
;
make_segment proc near

	push	ebx
	mov	ebx,[esp+8]	;ｾｸﾞﾄﾒﾝﾄﾍﾟｰｼﾞ数
	mov	ah,48h		;新規ｾｸﾞﾒﾝﾄ取得
	int	21h		;ｼｽﾃﾑｺｰﾙ（結果→eax）

	jc	short mseg_err	;ｷｬﾘｰが1 ならｴﾗｰへ
	pop	ebx
	ret

mseg_err:	;エラー
	mov	eax,ebx		;ﾘﾀｰﾝ ｺｰﾄﾞの
	shl	eax,16		; 上位16ﾋﾞｯﾄに割り当て可能最大ﾍﾟｰｼﾞ数を
	mov	ax,0ffffh	;異常終了コード
	pop	ebx
	ret

make_segment endp


	align	4
;------------------------------------------------------------------------------
;●指定セグメントの開放
;------------------------------------------------------------------------------
;int make_selector(int selector)
;	　戻り値　０＝正常終了
;	　　それ以外＝異常終了（９ならば無効なセレクタ）
;
free_segment proc near

	push	es
	mov	eax,[esp+8]	;ｾｸﾞﾄﾒﾝﾄｾﾓｸﾀ
	verr	ax		;ｾﾚｸﾀﾁｪｯｸ
	jz	short fseg_err	; 違法ならば､ｴﾗｰへ
	mov	es,ax		;開放するｾﾚｸﾀ
	mov	ah,49h		;ｾｸﾞﾒﾝﾄ開放
	int	21h

	jc	short fseg_err	;ｷｬﾘｰが1 ならｴﾗｰへ
	xor	eax,eax		;ﾘﾀｰﾝｺｰﾄﾞ eax=0
	pop	es
	ret

fseg_err:	;エラー
	or	al,1		;ﾘﾀｰﾝ ｺｰﾄﾞ0以外に
	pop	es
	ret


free_segment endp


	align	4
;------------------------------------------------------------------------------
;●ＧＤＴ／ＬＤＴ／ＩＤＴのディスクリプタ情報取得
;------------------------------------------------------------------------------
;int get_dt(int selector,struct descriptor *descriptor)
;
;   selector ＝ セレクタ値
;		bit 16 を｢1｣にすると IDTを指定した事になる(下位が割り込み番号)
;
;　 戻り値０＝正常：ﾒﾓﾘ 形式
;　 	　１＝ 〃 ：ｼｽﾃﾑ形式
;　 	　２＝ 〃 ：ｹﾞｰﾄ形式
;	　４＝使用不可能なセレクタ
;
;	※セグメントタイプは、システム・ゲート型ディスクリプタでは、
;	　メモリ型と判別するため、意図的に +16(bit4 が 1)されています。
;
;// メモリ･セグメント形式
;struct	mem_descriptor
;{
;	long	base;		// ﾘﾆｱ空間ﾍﾞｰｽｵﾌｾｯﾄ
;	long	limit;		// ﾘﾐｯﾄ値(byte)
;	char	level;		// ｾｸﾞﾒﾝﾄ使用可能ﾚﾍﾞﾙ
;	char	type;		// ｾｸﾞﾒﾝﾄﾀｲﾌﾟ
;	char	use;		// use サイズ
;};
;
;// システム･セグメント形式
;struct	sys_descriptor
;{
;	long	base;		// ﾘﾆｱ空間ﾍﾞｰｽｵﾌｾｯﾄ
;	long	limit;		// ﾘﾐｯﾄ値(byte)
;	char	level;		// ｾｸﾞﾒﾝﾄ使用可能ﾚﾍﾞﾙ
;	char	type;		// ｾｸﾞﾒﾝﾄﾀｲﾌﾟ
;};
;
;// ゲート･セグメント形式
;struct	gate_descriptor
;{
;	long	offset;		// ｵﾌｾｯﾄ
;	long	selector;	// ｾﾚｸﾀ(ｹﾞｰﾄﾃﾞｰﾀのある)
;	char	level;		// ｾｸﾞﾒﾝﾄ使用可能ﾚﾍﾞﾙ
;	char	type;		// ｾｸﾞﾒﾝﾄﾀｲﾌﾟ
;	char	dword_count;	// 呼び出し時ｽﾀｯｸｺﾋﾟｰ回数
;};
;
get_dt proc near

	push	edi
	push	esi
	push	es
	xor	eax, eax

	mov	edi,[esp+10h]	;指定ｾﾚｸﾀ値
	mov	esi,[esp+14h]	;構造体ｵﾌｾｯﾄ
	mov	ax,38h		;GDT を示すｾﾚｸﾀ値
	test	edi,4		;ｾﾚｸﾀ値のﾋﾞｯﾄ2をﾁｪｯｸ
	jz	short IDTchk	; 0 ならばGDT なのでこのままｼﾞｬﾝﾌﾟ
	mov	ax,30h		;LDT を示すｾﾚｸﾀ値
IDTchk:	test	edi,10000h	;bit 16 check
	jz	short StpIDT	;IDT を指定してなければジャンプ(bit16=0)
	mov	ax,50h		; IDT を示すセレクタ値
	and	edi,0ffffh	;IDT番号取得
	shl	edi,3		; 8 倍して IDT内オフセットへ
StpIDT:	mov	es,ax		;ｾﾚｸﾀ値ﾛｰﾄﾞ

	lsl	ecx, eax	; OS code
	cmp	edi, ecx
	ja	dt_not_found	; check GDT/LDT limit

	and	edi,0fff8h	;ﾃﾞｨｽｸﾘﾌﾟﾀは 8ﾊﾞｲﾄ単位なので下位3ﾋﾞｯﾄ切捨て
	mov	ecx,es:[edi]	;目的のｾﾚｸﾀから		ecx:下位
	mov	edx,es:[edi+4]	; 内容ﾛｰﾄﾞ（8 byte長）	edx:上位

	test	dx,8000h	;P ﾋﾞｯﾄをﾃｽﾄ
	jnz	short dt_step0	;1 なら存在なので処理続行(=JMP)



dt_not_found:
	;存在しなければリターン
	mov	eax,4	;ﾘﾀｰﾝｺｰﾄﾞ
	pop	es
	pop	esi
	pop	edi
	ret

	align	4
;###セグメント解析###
dt_step0:
	;特権レベル取得
	mov	al,dh
	shr	al,5		;↑DPL(特権ﾚﾍﾞﾙ)ﾌｨｰﾙﾄﾞ
	and	al,03h		;↓ のみ取り出す
	mov	[esi+8],al	;構造体にｺﾋﾟｰ

	;ｾｸﾞﾒﾝﾄTYPE取得
	mov	al,dh
	and	al,0fh		;TYPE ﾌｨｰﾙﾄﾞのみ取り出す

	xor	edi,edi		;edi=0 ←戻り値に使う
	test	dx,1000h	;DTYPE ﾋﾞｯﾄをﾃｽﾄ
	jnz	short mem_seg	;1 ならばﾒﾓﾘ･ｾｸﾞﾒﾝﾄ


	;ｼｽﾃﾑ/ｹﾞｰﾄ･ｾｸﾞﾒﾝﾄ形式
	mov	di,1		;edi=1 ←戻り値に使う(1=ｼｽﾃﾑ形式)
	or	al,10h		;TYPE+=16
	test	al,04h		;ﾋﾞｯﾄ2を調べる
	jz	short sys_seg	;1 ならばｼｽﾃﾑｾｸﾞﾒﾝﾄなので、後はﾒﾓﾘと同じ

;###ゲート・セグメント形式###
	mov	ah,dl		;Dword Countを上位へ
	mov	[esi+9],ax	;構造体にｾｸﾞﾒﾝﾄﾀｲﾌﾟとDowrd Countを記録
				;[esi+9]=type [esi+10]=Dowrd Count

	mov	dx,cx		;ｵﾌｾｯﾄの bit0～15 を ｺﾋﾟｰし
	mov	[esi],edx	; edx の上位(bit16～31)と合わせ、ｵﾌｾｯﾄを記録

	shr	ecx,16		;ecx のbit16～31に収まっている、ｾﾚｸﾀを下位に
	mov	[esi+4],ecx	;ｾﾚｸﾀを構造体にコピー

	mov	eax,2	;ﾘﾀｰﾝｺｰﾄﾞ
	pop	es
	pop	esi
	pop	edi
	ret

	align	4
;###メモリ/システム(TSS)・セグメント形式###
mem_seg:
	mov	ah,32		;use32
	test	edx,400000h	;ﾃﾞｨﾌｫﾙﾄﾀｲﾌﾟﾋﾞｯﾄﾁｪｯｸ
	jnz	short _use32	; 1 なら use32
	mov	ah,16		; 0 なら use16
_use32:	mov	[esi+10],ah	;use 型を構造体に記録
sys_seg:
	mov	[esi+9],al	;構造体にｾｸﾞﾒﾝﾄﾀｲﾌﾟ記録
	;ﾘﾐｯﾄ値取得
	mov	eax,edx
	and	eax,000f0000h	;ﾘﾐｯﾄ値取得 bit16～19
	mov	ax,cx		;ﾘﾐｯﾄ値ｺﾋﾟｰ bit 0～15
	inc	eax		;ﾘﾐｯﾄ→ｻｲｽﾞ
	shr	ecx,16		;ecx の上位を下位へ
	test	edx,00800000h	;G ﾋﾞｯﾄをﾁｪｯｸ
	jz	short ms_step0	;0 ならｽﾃｯﾌﾟ
	shl	eax,12		;1 なら 4Kbyte 単位なので ×1000h
ms_step0:
	mov	[esi+4],eax	;ﾘﾐｯﾄ値を構造体にｺﾋﾟｰ

	;ﾍﾞｰｽｵﾍｾｯﾄ取得
	xor	eax,eax		;eax=0
	mov	ah,dl		;ﾍﾞｰｽｵﾌｾｯﾄ bit16～23
	shl	eax,8		;ｼﾌﾄ
	and	edx,0ff000000h	;bit 24～31
	or	eax,edx		;bit 16～31 までｾｯﾄ完了
	mov	ax,cx		;bit  0～16 もｾｯﾄ
	mov	[esi],eax	;構造体にｺﾋﾟｰ

	mov	eax,edi		;戻り値=0(ﾒﾓﾘｾｸﾞﾒﾝﾄ)
	pop	es
	pop	esi
	pop	edi
	ret

get_dt endp


	align	4
;------------------------------------------------------------------------------
;●セレクタ値のリミット値を取得する
;------------------------------------------------------------------------------
;int get_limit(int selector)
;
;	selector ＝ディスクリプタ･セレクタ
;
;	戻り値   ＝リミット値
;
;	存在しないセレクタや無効な型を持つセレクタを指定すると、
;	その時点でフォールトが発生しプログラムが止まってしまいます。
;
get_limit proc near
	mov	eax,[esp+4]	;引数
	lsl	eax,eax		;リミット値ロード特権命令
	ret

get_limit endp


	align	4
;------------------------------------------------------------------------------
;●セレクタ値のリニア空間オフセットを取得する
;------------------------------------------------------------------------------
;int get_linear_offset(int selector)
;
;	selector ＝ディスクリプタ･セレクタ
;
;	戻り値   ＝リニア空間オフセット
;
;	ノーチェックでオフセットにあたるメモリを参照しますので、
;	正常なメモリ形式セグメントを指定しないと、無意味な結果を返します。
;
get_linear_offset proc near
	push	es

	mov	edx,[esp+8]	;指定ｾﾚｸﾀ値
	mov	ax,38h		;GDT を示すｾﾚｸﾀ値
	test	edx,4		;ｾﾚｸﾀ値のﾋﾞｯﾄ2をﾁｪｯｸ
	jz	short GDT_	; 0 ならばGDT なのでこのままｼﾞｬﾝﾌﾟ
	mov	ax,30h		;LDT を示すｾﾚｸﾀ値
GDT_:	mov	es,ax		;ｾﾚｸﾀ値ﾛｰﾄﾞ
	and	edx,0fff8h	;ﾃﾞｨｽｸﾘﾌﾟﾀは 8ﾊﾞｲﾄ単位なので下位3ﾋﾞｯﾄ切捨て

	;ﾘﾆｱ空間ﾍﾞｰｽｵﾍｾｯﾄ取得
	mov	eax,es:[edx+4]	;ｵﾌｾｯﾄ領域 bit24～31
	mov	ecx,es:[edx+2]	;　　　　　bit 0～23
	and	eax,0ff000000h	;オフセット部分
	and	ecx,000ffffffh	;　のみ取り出し
	or	eax,ecx		;ふたつを合成して、ｵﾌｾｯﾄを取得

	pop	es
	ret

get_linear_offset endp


	align	4
;------------------------------------------------------------------------------
;●リニア空間オフセットを物理アドレスに変換する
;------------------------------------------------------------------------------
;******************************************************************************
;int linear_to_physical(int linear_offset)
;
;	linear_offset ＝リニア空間オフセット
;
;	戻り値　　    ＝物理アドレス
;
;　注意：そのアドレスがメモリ上に存在しない場合、戻り値は不定です。
;　　　　仮想記憶使用中は、使用しないでください（対応してるの知らないけど…）。
;
linear_to_physical proc near
	push	ebx

	mov	ebx,[esp+8]	;リアニ空間オフセット
	mov	ax,2509h	;リニア→物理 アドレス変換 
	int	21h
	jnc	short ex2509_s
	mov	ecx,-1
ex2509_s:
	mov	eax,ecx		;戻り値に記録

	pop	ebx
	ret

linear_to_physical endp


	align	4
;------------------------------------------------------------------------------
;●セレクタ値とセレクタ内オフセットから物理アドレスを取得する
;------------------------------------------------------------------------------
;int get_physical_address(int offset,int selector)
;
;	selector ＝ディスクリプタ･セレクタ
;	offset   ＝セレクタ内オフセット
;
;	戻り値   ＝物理アドレス
;
;　注意：一切チェックは入れてありませんので、
;　　　　必ず実在するアドレスを指定してください。
;
get_physical_address proc near
	push	ebx

	mov	ebx,[esp+0ch]	;セレクタ
	mov	ax,2508h	;セレクタのリニア空間アドレス取得
	int	21h		;→ecx

	mov	ebx,[esp+08h]	;セレクタ内オフセットロード
	add	ebx,ecx		;セレクタ内オフセットにセレクタベースを足す
	mov	ax,2509h	;リニア→物理 アドレス変換 
	int	21h

	mov	eax,ecx		;戻り値に記録

	pop	ebx
	ret

get_physical_address endp


	align	4
;------------------------------------------------------------------------------
;●新規にＬＤＴ作成し、現在のＬＤＴ内容を複写する
;------------------------------------------------------------------------------
;void make_new_ldt(int selctor,void *offset,int size);
;
;	　　　　　↓ＬＤＴを新規に作成するメモリの
;	selctor ＝ セレクタ
;	offset  ＝ オフセット
;	size    ＝ 大きさ(byte) 下位16ビットのみ使用 1～0ffffh 0=64KB
;
;　　与えられたメモリアドレスから４ＫＢを、ＬＤＴとして使用します。
;　　それまで使用してきたＬＤＴセレクタ値（x4h,xCh）はそのまま利用できます。
;
make_new_ldt proc near
	push	ebp
	mov	ebp,esp
	push	ebx
	push	edi
	push	esi
	push	es
	push	ds


	;##### ＬＤＴ内容を複写 ###########################
	mov	eax,[ebp+08h]	;LDT作成 ｾﾚｸﾀ 値｜es :コピー先セグメント
	mov	es,ax		;　eax の値は保持する
	mov	edi,[ebp+0ch]	;LDT作成 ｵﾌｾｯﾄ値｜edi:コピー先オフセット
	mov	ebp,edi		;  ebp に値を保存

	mov	ecx,30h
	mov	ds,cx		;コピー元セグメント=30h(LDTｱｸｾｽｾﾚｸﾀ)
	xor	esi,esi		;コピー元オフセット=0

	lsl	ecx,ecx		;現ＬＤＴのリミット値ロード
	inc	ecx		; +1 をする事で、ＬＤＴサイズに
	shr	ecx,2		;ダブルワード転送なので、÷４
	rep movsd		;一括転送（ES:EDI ← DS:ESI）


	;現レジスタ ax:edx＝新LDT作成アドレス

	;##### ｾﾚｸﾀ＋ｵﾌｾｯﾄをリニア空間ｵﾌｾｯﾄに変換 #########
	pop	ds			;ds を復元
	push	eax			;セレクタ値をプッシュ
	call	get_linear_offset	;リニア空間オフセットを取得→eax
	pop	ecx			;積んだスタックを取り除く
	add	eax,ebp			;セレクタ内オフセットを加算
	mov	edx,eax			;edx に複写


	;現レジスタ eax = edx = 新LDTﾘﾆｱ空間ｱﾄﾞﾚｽ（＝ベースオフセット）

	;##### GDT内 LDTｾﾚｸﾀ･LDTｱｸｾｽ用ｾﾚｸﾀ更新 ############
	mov	edi,28h		;GDT 内 LDTセレクタ値(GDT内ｱﾄﾞﾚｽ)
				;	LDTアクセス用ｾﾚｸﾀは 30h(=edi+8)
	mov	cx,38h		;GDT を指し示す
	mov	es,cx		; セレクタ値を es にロード

	shl	eax,16		;ﾍﾞｰｽｵﾌｾｯﾄのbit0～15 をebx のbit16～31へ
	mov	ax,[esp+20h]	;サイズをロード
	dec	ax		;-1 してリミット値に
	mov	es:[edi  ],eax	;GDT内 LDTに設定
	mov	es:[edi+8],eax	;GDT内 LDTｱｸｾｽｾﾚｸﾀに設定

	mov	eax,es:[edi+4]	;セレクタの内容ロード(LDT)
	mov	ecx,edx		;ベースオフセットをコピー →ecx
	shr	ecx,8		;ベースオヘセットのbit16～23 を bh ﾚｼﾞｽﾀに
	mov	al,ch		; それをセレクタ内容の下位8bitへロード

	and	edx,0ff000000h	;ベースオフセットのbit24～31のみ取り出す
	and	eax,00070ffffh	;セレクタ内容をマスクする(同時に G bit＝0)
	or	eax,edx		;合成
	mov	es:[edi+4],eax	;GDT内 LDTレジスタに設定

	mov	eax,es:[edi+12]	;セレクタの内容ロード(LDTｱｸｾｽｾﾚｸﾀ)
	mov	al,ch		; それをセレクタ内容の下位8bitへロード
	and	eax,00070ffffh	;セレクタ内容をマスクする(同時に G bit＝0)
	or	eax,edx		;ベースオフンセットと合成
	mov	es:[edi+12],eax	;GDT内 LDTアクセスセレクタに設定

	;##### 新LDT をロードする #########################
	mov	ax,28h		;GDT内 LDTセレクタ
	LLDT	ax		;新規に作成した LDTをロードする


	;##### 復帰処理 ###################################
	pop	es
	pop	esi
	pop	edi
	pop	ebx
	pop	ebp
	ret

make_new_ldt endp


	align	4
;------------------------------------------------------------------------------
;●３８６形式のメモリセグメントを作成します
;------------------------------------------------------------------------------
;void make_mems(int selctor,struct mem_descriptor *memd)
;
;	selctor	＝ セレクタ値（作成するセレクタ値）
;
;struct	mem_descriptor
;{
;	int	base;	// リニア空間ベースオフセット
;	int	limit;	// サイズ（単位 byte）：必ず 0 以外の数を指定する事
;	char	level;	// 特権レベル(0～3)
;	char	type;	// メモリセグメントタイプ（get_gdtのﾀｲﾌﾟ定義参照）
;};		   	//  必ず 00h～0fh(0～15) の間の値であること。
;
;
make_mems	proc near
	push	ebp
	mov	ebp,esp
	push	ebx
	push	edi
	push	es

	mov	ebx,[ebp+08h]	;指定ｾﾚｸﾀ値
	mov	edi,[ebp+0ch]	;ﾃﾞｨｸﾘﾌﾟﾀ型を示す構造体ｵﾌｾｯﾄ

	mov	ax,38h		;GDT を示すｾﾚｸﾀ値
	test	ebx,4		;ｾﾚｸﾀ値のﾋﾞｯﾄ2をﾁｪｯｸ
	jz	short GDT_M	; 0 ならばGDT なのでこのままｼﾞｬﾝﾌﾟ
	mov	ax,30h		;LDT を示すｾﾚｸﾀ値
GDT_M:	mov	es,ax		;ｾﾚｸﾀ値ﾛｰﾄﾞ

	and	ebx,0fff8h	;ﾃﾞｨｽｸﾘﾌﾟﾀは 8ﾊﾞｲﾄ単位なので下位3ﾋﾞｯﾄ切捨て

	mov	edx,[edi+4]	;ﾘﾐｯﾄ値
	mov	es:[ebx],dx	;ﾘﾐｯﾄ値をﾃｰﾌﾞﾙにｾｯﾄ bit0～15
	and	edx,0f0000h	;ﾘﾐｯﾄ値の bit16～19 を取り出す
	or	edx,0c00000h	;属性 386形式

	mov	eax,[edi]	;ﾍﾞｰｽｵﾌｾｯﾄﾛｰﾄﾞ
	mov	es:[ebx+2],ax	;ﾍﾞｰｽ bit0～15
	mov	ecx,eax
	shr	ecx,8		;ﾍﾞｰｽの bit16～23
	and	eax,0ff000000h	;ﾍﾞｰｽの bit24～31
	mov	dl,ch		;bit 16～23ｾｯﾄ
	or	edx,eax		;bit 24～31ｾｯﾄ

	mov	ax,[edi+8]	;特権ﾚﾍﾞﾙ(dl) と ｾｸﾞﾒﾝﾄﾀｲﾌﾟ(dh)をﾛｰﾄﾞ
	shl	al,5		;bit5･6 の位置にもってくる
	or	al,ah		;特権レベルとセグメントタイプを混ぜる
	or	al,90h		;存在する(80h) 存在ビット(Pビット) を 1に
	mov	dh,al		;記録用ﾚｼﾞｽﾀに格納   　＋DT1(mem 形式):10h
	mov	es:[ebx+4],edx	;ﾃｰﾌﾞﾙに記録

	pop	es
	pop	edi
	pop	ebx
	pop	ebp
	ret
make_mems endp


	align	4
;------------------------------------------------------------------------------
;●ＴＳＳ[Task State Segment]－ディスクリプタを作成する
;------------------------------------------------------------------------------
;void make_tss(int selector,struct tss_descriptor *tssd)
;	※規定外の値を指定しても、動作しますが、使用時大変危険です
;
;struct	tss_descriptor
;{
;	int	base;		// ﾘﾆｱ空間ﾍﾞｰｽｵﾌｾｯﾄ
;	int	limit;		// ﾘﾐｯﾄ(byte 単位)
;	char	level;		// 特権ﾚﾍﾞﾙ
;};
;
make_tss proc near

	push	edi
	push	esi
	push	es

	mov	edi,[esp+10h]	;TSS を作成するｾﾚｸﾀ値
	mov	esi,[esp+14h]	;TSSS構造体へのポインタ

	mov	ax,38h		;GDT を示すｾﾚｸﾀ値
	test	edi,4		;ｾﾚｸﾀ値のﾋﾞｯﾄ2をﾁｪｯｸ
	jz	short GDT_T	; 0 ならばGDT なのでこのままｼﾞｬﾝﾌﾟ
	mov	ax,30h		;LDT を示すｾﾚｸﾀ値
GDT_T:	mov	es,ax		;ｾﾚｸﾀ値ﾛｰﾄﾞ

	and	edi,0fff8h	;ﾃﾞｨｽｸﾘﾌﾟﾀは 8ﾊﾞｲﾄ単位なので下位3ﾋﾞｯﾄ切捨て
	mov	edx,[esi+4]	;ﾘﾐｯﾄ値
	mov	es:[edi],dx	;ﾘﾐｯﾄ値をﾃｰﾌﾞﾙにｾｯﾄ bit0～15
	and	edx,0f0000h	;ﾘﾐｯﾄ値の bit16～23 を取り出す

	mov	eax,[esi]	;ﾍﾞｰｽｵﾌｾｯﾄﾛｰﾄﾞ
	mov	es:[edi+2],ax	;ﾍﾞｰｽ bit0～15
	mov	ecx,eax
	shr	ecx,8		;ﾍﾞｰｽの bit16～23
	and	eax,0ff000000h	;ﾍﾞｰｽの bit24～31
	mov	dl,ch		;bit 16～23ｾｯﾄ
	or	edx,eax		;bit 24～31ｾｯﾄ

	mov	dh,[esi+8]	;特権ﾚﾍﾞﾙﾛｰﾄﾞ
	shl	dh,5		;bit5･6 の位置にもってくる
	or	dh,89h		;386利用可TSS(9h)・存在する(80h)
	mov	es:[edi+4],edx	;ﾃｰﾌﾞﾙに記録

	pop	es
	pop	esi
	pop	edi
	ret

make_tss endp




	align	4
;------------------------------------------------------------------------------
;●ゲートのディスクリプタを作成する
;------------------------------------------------------------------------------
;void make_gate(int selector,struct gate_descriptor *gated)
;	selector ＝ ゲートディスクリプタ･セレクタ
;
;struct	gate_descriptor
;{
;	long	offset;		// ｵﾌｾｯﾄ
;	long	selector;	// ｾﾚｸﾀ(ｹﾞｰﾄﾃﾞｰﾀのある)
;	char	level;		// ｾｸﾞﾒﾝﾄ使用可能ﾚﾍﾞﾙ
;	char	type;		// ｾｸﾞﾒﾝﾄﾀｲﾌﾟ(0～15)
;	char	dword_count;	// 呼び出し時ｽﾀｯｸｺﾋﾟｰ回数
;};	// ﾃﾞｨｽｸﾘﾌﾟﾀ･ﾃｰﾌﾞﾙ情報取得(get_dt)の時に使うものと同じ形式
;
make_gate proc near

	push	edi
	push	esi
	push	es

	mov	edi,[esp+10h]	;ゲートを作成するｾﾚｸﾀ値
	mov	esi,[esp+14h]	;ゲート構造体へのポインタ

	mov	ax,38h		;GDT を示すｾﾚｸﾀ値
	test	edi,4		;ｾﾚｸﾀ値のﾋﾞｯﾄ2をﾁｪｯｸ
	jz	short GDT_G	; 0 ならばGDT なのでこのままｼﾞｬﾝﾌﾟ
	mov	ax,30h		;LDT を示すｾﾚｸﾀ値
GDT_G:	mov	es,ax		;ｾﾚｸﾀ値ﾛｰﾄﾞ

	and	edi,0fff8h	;ﾃﾞｨｽｸﾘﾌﾟﾀは 8ﾊﾞｲﾄ単位なので下位3ﾋﾞｯﾄ切捨て
	mov	ecx,[esi+2]	;ecx 上位16bit にセレクタ値を
	mov	eax,[esi]	;ｵﾌｾｯﾄをロード
	mov	cx,ax		;ecx 下位16bit にｵﾌｾｯﾄの bit0～15を
	mov	es:[edi],ecx	;ｾﾚｸﾀ + ｵﾌｾｯﾄ(bit0～15) をﾃﾞｨｽｸﾘﾌﾟﾀに記録

	mov	ah,[esi+8]	;ﾚﾍﾞﾙを ah に
	mov	cl,[esi+9]	;ﾀｲﾌﾟをｺﾋﾟｰ
	mov	al,[esi+10]	;dword count を al に（ｽﾀｯｸｺﾋﾟｰ回数）
	shl	ah,5		;ﾚﾍﾞﾙを記録用のビット位置に(bit5･6)
	or	ah,cl		;ﾀｲﾌﾟ(bit0～3) を記録用ﾚｼﾞｽﾀに混ぜる
	or	ah,80h		;ゲート存在を 1(存在する)に
	mov	es:[edi+4],eax	;残りの情報をﾃﾞｨｽｸﾘﾌﾟﾀに記録

	pop	es
	pop	esi
	pop	edi
	ret

make_gate endp



;------------------------------------------------------------------------------
;●レジスタのロード・ストア
;------------------------------------------------------------------------------
;
	align	4
store_tr proc	near		;ＴＲレジスタへのＴＳＳロード
	mov	eax,[esp+4]
	ltr	ax
	ret
store_tr endp

	align	4
load_tr	proc	near		;ＴＲからＴＳＳを読み込む
	xor	eax,eax
	str	ax
	ret
load_tr	endp

load_cs	proc near		;ＣＳレジスタの内容をロード
	xor	eax,eax
	mov	ax,cs
	ret
load_cs	endp

load_ds	proc near		;ＤＳレジスタの内容をロード
	xor	eax,eax
	mov	ax,ds
	ret
load_ds	endp

load_far_mem	proc near
	push	es
	push	edi
	mov	eax,[esp+12]
	mov	es,ax
	mov	edi,[esp+16]
	mov	eax,es:[edi]
	pop	edi
	pop	es
	ret
load_far_mem	endp



;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
code	ends



data	segment
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
data	ends
	end
