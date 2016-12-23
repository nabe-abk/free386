
;************************************************
;Header file for NASM
;		Copyright (C) 2000  ABK project
;************************************************
;
;	2000/07/12 çÏê¨
;

%define	b	byte
%define	w	word
%define	d	dword

%define retf	db 0cbh
%define callf	call dword far

%define	public	global
%define	offset

%macro	proc	1
	global	%1
	align	32
	%1:
%endmacro

