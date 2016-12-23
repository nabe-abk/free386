
;************************************************
;Header file for NASM
;		Copyright (C) 2000  ABK project
;************************************************
;
;	2000/07/12 çÏê¨
;

%define	s	short
%define	b	byte
%define	w	word
%define	d	dword

%define far_ret		db 0cbh
%define callf	call dword far

%define	public	global
%define	extrn	extern
%define	ptr
%define	offset

%macro	proc	1
	global	%1
	align	4
	%1:
%endmacro



%define	Cy_flag		01h


;
;****** use on nasm / pushfw,popfw
;	thanks to Mamiya (san)
;;%define pushf db 0x66, 0x9C
;;%define popf  db 0x66, 0x9D
