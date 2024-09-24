
extern	int		is_support();
extern	void		start_vsync();
extern	void		stop_vsync();
extern	unsigned int	get_millisec_count();
extern	void		syscall_int21_0Bh();
extern	void		vram120_write_256byte(int offset, int val);

#define	MACHINE_PC98	0x10
#define	MACHINE_TOWNS	0x20
#define	MACHINE_AT	0x30

