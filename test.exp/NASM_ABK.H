
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

%define retf	db 0cbh
%define callf	call dword far

%define	public	global
%define	extrn	extern
%define	ptr
%define	offset

%macro	proc	1
	global	%1
	align	32
	%1:
%endmacro


%define	Cy_flag		01h

