
///// benchmark /////

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "lib/benchlib.h"

#define uint unsigned int

#define TEST1_NUM  20000
#define TEST2_MB   128
#define TEST3_MB   128
#define TEST4_NUM  50000

///////////////////////////////////////////////////////////////////////////////

int test_prime(int x) {
	if (!(x & 1)) return 0;
	if (  x < 4 ) return 1;

	int y = sqrt(x) +1;

	for(int i=3; i<y; i+=2) {
		int m = x % i;
		if (!m) return 0;
	}
	return 1;
}

uint test1(int mul) {
	printf("[Test1] Prime numbers less than %d : ", TEST1_NUM*mul);
	uint st = get_millisec_count();
	int cnt = 1;
	for(int i=2; i<TEST1_NUM*mul; i++) {
		cnt+= test_prime(i);
	}
	uint ed = get_millisec_count();
	uint diff = st<ed ? (ed - st) : (0xffffffff - (st - ed -1));
	printf("%d // %d ms\n", cnt, diff);

	return diff;
}

uint test2(int mul) {
	int *buf = calloc(1024 * 1024/4, sizeof(int));	// clear for page table cache

	printf("[Test2] Memory read/write %d MB, p=%p ", TEST2_MB*mul, buf);

	uint st = get_millisec_count();
	for(int j=0; j<TEST2_MB*mul; j++) {
		for(int i=0; i < 1024*1024/16; i++) {
			buf[i   ] = i;	
			buf[i+4 ] = i;
			buf[i+8 ] = i;
			buf[i+12] = i;
		}
	}
	uint ed = get_millisec_count();
	uint diff = st<ed ? (ed - st) : (0xffffffff - (st - ed -1));
	printf("// %d ms\n", diff);
	free(buf);

	return diff;
}

uint test3(int mul) {
	printf("[Test3] VRAM read/write %d MB               ", TEST3_MB*mul);

	uint st = get_millisec_count();
	for(int j=0; j<TEST3_MB*mul *4; j++) {
		for(int i=0; i < 256*1024; i+=256) {	// write 256KB
			vram120_write_256byte(i, 0x00000000);	// offset, val(dword)
		}
	}
	uint ed = get_millisec_count();
	uint diff = st<ed ? (ed - st) : (0xffffffff - (st - ed -1));
	printf("// %d ms\n", diff);

	return diff;
}

uint test4(int mul) {
	printf("[Test4] system call int 21/0Bh   %d times ", TEST4_NUM*mul);

	uint st = get_millisec_count();
	for(int i=0; i<TEST4_NUM*mul; i++) {
		syscall_int21_0Bh();
	}
	uint ed = get_millisec_count();
	uint diff = st<ed ? (ed - st) : (0xffffffff - (st - ed -1));
	printf("// %d ms\n", diff);

	return diff;
}

int main()
{
	printf("Easy benchmark by nabe@abk - 2024-09-24\n\n");

	int type = is_support();
	if (!type) {
		printf("This program support: TOWNS or PC-98 or PC/AT with VESA 2.0\n");
		exit(1);
	}
	start_vsync();

	if (test1(1) <100) test1(100);
	if (test2(1) <100) test2(100);
	if (test3(1) <100) test3(100);
	test4(1);

	stop_vsync();
	return 0;
}
