
extern	make_selector		;386�`���������Z���N�^�쐬
extern	make_selector_4k		;386�`���������Z���N�^�쐬 (4KB �P��)
extern	set_physical_mem	;�������������w�胊�j�A�A�h���X�ɔz�u����
extern	alloc_DOS_mem		;DOS��������\��t��
extern	alloc_RAM		;RAM �����j�A�A�h���X�ɔz�u����
extern	alloc_RAM_with_ladr	;RAM ���w��̃��j�A�A�h���X�ɔz�u����

extern	map_memory		;�e�[�u����ǂݏo���A�������������Z���N�^�ɔz�u
extern	make_aliases		;�Z���N�^�̃G�C���A�X���쐬����i�e�[�u���Q�Ɓj
extern	make_alias		;�G�C���A�X���쐬����

extern	get_maxalloc		;�ő劄�蓖�ĉ\������(page)�擾
extern	get_maxalloc_with_adr	;�ő劄�蓖�ĉ\������(page)�擾
extern	get_selector_last	;�Z���N�^�Ō�����j�A�A�h���X(+1)�擾

extern	sel2adr			;�Z���N�^�l to �A�h���X�ϊ�
extern	search_free_LDTsel	;��LDT�Z���N�^�̌���
extern	selector_reload		;�S�f�[�^�Z���N�^�̃����[�h