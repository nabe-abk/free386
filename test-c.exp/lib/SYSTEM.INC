;
;�V�X�e���֘A��`�p�C���N���[�h�t�@�C���i�A�Z���u���p�j
;
;1998/02/24
;1998/03/24
;
;[TAB=8]
;/////�@���荞�ݒ�` //////////////////////////////////////////////////////////

;���A�����[�h����h���C�o�Ŏg�p���銄�荞��

Interrupt_No		equ	0e2h	;�v���O�����g�p Int �ԍ�
Int_NO_str_H		equ	'e'	;���b�Z�[�W�\���p�@�Q�P�^��
Int_NO_str_L		equ	'2'	;�@�@�@�@�@�@�@�@�@�P�P�^��

kernel_call_int		equ	0e3h	;�J�[�l���R�[���Ɏg�p Int �ԍ�

kernel_call	macro
	int	kernel_call_int
	endm


;/////�@�ȉ��Z�O�����g��` ////////////////////////////////////////////////////
;
;	���݂͊g�������k�c�s�́A0f04h�`0ffch ���g�p���Ă��܂��B
;

LDT_limit		equ	0fffh	;���~�b�g�l�F�VLDT�T�C�Y��4KB

;�����̂����܂�͎��ۂɂ͑��l�ŏ����Ă邯�ǁc�c(^^;;
NULL_SEL		equ	0000h	;�k���Z���N�^
LDT_SEL 		equ	0028h	;�k�c�s�Ƀ��[�h�����Z���N�^
LDT_access_SEL		equ	0030h	;�k�c�s�A�N�Z�X�ɗp����Z���N�^
GDT_access_SEL		equ	0038h	;�f�c�s�A�N�Z�X�ɗp����Z���N�^
IDT_access_SEL		equ	0050h	;�h�c�s�A�N�Z�X�ɗp����Z���N�^

DOS_MEM_SEL		equ	0034h	;DOS���(1MB�ȉ�)�ɱ����Ɏg�p����ڸ�

KERNEL_CS		equ	000ch	;�J�[�l���̃R�[�h�Z�O�����g�Z���N�^
KERNEL_DS		equ	0014h	;�J�[�l���̃f�[�^�Z�O�����g�Z���N�^

;----------------------------------------------------------------------------

TSS_access		equ	0e04h	;TSS �����p�ڸ�
IOPL_adress 		equ	1000h	; TSS�� IOPL �A�h���X


