
///// �f�B�X�N���v�^�e�[�u������ /////

#include <stdio.h>
#include <stdlib.h>
#include "lib/mtask.h"


#define	ldt_size	0x10000

void main()
{
	descriptor	des;	// �ި�������\����
	struct mem_descriptor	mdes;	// �ި�������\����

	int sel,s;
	char	*new_ldt;
	int	*p;

	new_ldt = (char *) calloc(ldt_size,sizeof(char));	// 4KB

	make_new_ldt(0x14,new_ldt,ldt_size);

	mdes.base	=0x12345;
	mdes.limit	=0x77777;
	mdes.level	=0x00;
	mdes.type	=0x2;
	make_mems(0x134, &mdes);
/*
	printf("PSP 5ch : %08xh\n", load_far_mem(0x24, (void *)0x5c));
	printf("PSP 60h : %08xh\n", load_far_mem(0x24, (void *)0x60));
	printf("PSP 64h : %08xh\n", load_far_mem(0x24, (void *)0x64));
*/
/*	for(int i=0x100; i<0x10000; i++) {
		p = (int *)(i*1024);
		*p = 0x1234;
		sel = *p;
		if (sel != 0x1234) {
			printf("Error %08x\n", i*1024);
		}
	}
*/

while(1){

	printf("\n�Z���N�^[Hex]('ff'�ŏI��)�H");
	scanf("%X",&sel);
	if (sel==0xf || sel==0xff) break;

	s=get_dt(sel, &des);

	if (s & 4)
		 printf("���݂��܂���\n");
	else if (s==0) {
		printf("�������E�Z�O�����g�`��\n");
		printf("�x�[�X��%8xh\n",des.mem.base);
		printf("�T�C�Y��%8xh\n",des.mem.limit);
		printf("���x����%d\n"  ,des.mem.level);
		printf("�^�C�v��%s\n"  ,sd_type[des.mem.type]);
		printf("��������%d\n"  ,des.mem.use);
	} else if (s==1) {
		printf("�V�X�e���E�Z�O�����g�`��\n");
		printf("�x�[�X��%8xh\n",des.sys.base);
		printf("�T�C�Y��%8xh\n",des.sys.limit);
		printf("���x����%d\n"  ,des.sys.level);
		printf("�^�C�v��%s\n"  ,sd_type[des.sys.type]);
	} else if (s==2) {
		printf("�Q�[�g�E�Z�O�����g�`��\n");
		printf("�̾�� ��%8xh\n",des.gate.offset);
		printf("�ڸ��l��%8xh\n",des.gate.selector);
		printf("���x����%d\n"  ,des.gate.level);
		printf("�^�C�v��%s\n"  ,sd_type[des.gate.type]);
	}
}
}