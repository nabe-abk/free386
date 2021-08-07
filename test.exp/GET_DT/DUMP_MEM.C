
///// ÉÅÉÇÉäÉ_ÉìÉv /////

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "mtask.h"


void main()
{
	int		i,j;
	descriptor	des;

	i = mma_allocSeg("FONT");
	printf("mma_AllocSeg(FONT) : %xh\n", i);


	printf("GDT Segment List:\n");
	for(i=8; i<0x200; i+=8) {
		int r = get_dt(i, &des);
		if (r & 4) continue;	// not found

		char	*type;
		char	*sdt;
		long	base;
		long	size;
		int	level;
		char	buf[16];

		if (r==0) {
			type  = "MEM ";
			base  = des.mem.base;
			size  = des.mem.limit;
			level = des.mem.level;

			for(j=0; j<8; j++) buf[j]=' ';
			strcpy(buf, sd_type_s[ des.mem.type ]);
			if (des.mem.use == 16)
				strcat(buf, " 16");
			else
				strcat(buf, " 32");
			sdt=buf;

		} else if (r==1) {
			type  = "SYS ";
			base  = des.sys.base;
			size  = des.sys.limit;
			level = des.sys.level;
			sdt   = sd_type_s[ des.sys.type ];
		} else if (r==2) {
			type  = "GATE";
			base  = des.gate.offset;
			size  = 0;
			level = des.gate.level;
			sdt   = sd_type_s[ des.sys.type ];
		}
		if (base==0 && size==1) continue;
		printf("  %03Xh %s %6s %08Xh size=%08X L%d\n", i, type, sdt, base, size, level);
	}

	printf("\nLDT Segment List:\n");
	for(i=4; i<0x200; i+=8) {
		int r = get_dt(i, &des);
		if (r & 4) continue;	// not found

		char	*type;
		char	*sdt;
		long	base;
		long	size;
		int	level;
		char	buf[16];

		if (r==0) {
			type  = "MEM ";
			base  = des.mem.base;
			size  = des.mem.limit;
			level = des.mem.level;

			for(j=0; j<8; j++) buf[j]=' ';
			strcpy(buf, sd_type_s[ des.mem.type ]);
			if (des.mem.use == 16)
				strcat(buf, " 16");
			else
				strcat(buf, " 32");
			sdt=buf;

		} else if (r==1) {
			type  = "SYS ";
			base  = des.sys.base;
			size  = des.sys.limit;
			level = des.sys.level;
			sdt   = sd_type_s[ des.sys.type ];
		} else if (r==2) {
			type  = "GATE";
			base  = des.gate.offset;
			size  = 0;
			level = des.gate.level;
			sdt   = sd_type_s[ des.sys.type ];
		}
		if (base==0 && size==1) continue;
		printf("  %03Xh %s %6s %08Xh size=%08X L%d\n", i, type, sdt, base, size, level);
	}

	printf("\nPaging Info:\n");
	int adr[8];
	for(i=0; i<0x100000; i+=8) {
		int flag=1;
		for(j=0; j<8; j++) {
			int k = i+j;
			unsigned int off =  k << 12;
			unsigned int ad  = (linear_to_physical(off) >> 12) & 0xfffff;
			if (ad != 0xfffff) flag=0;
			adr[j] = ad;
		}
		if (flag) continue;
		printf("%08X : %05X %05X %05X %05X %05X %05X %05X %05X\n",
			i<<12, adr[0], adr[1], adr[2], adr[3], adr[4], adr[5], adr[6], adr[7]);
	}
}
