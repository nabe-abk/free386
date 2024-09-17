;******************************************************************************
;Å@Free386 pc model
;******************************************************************************

%include	"macro.inc"
%include	"f386def.inc"

%include	"start.inc"
%include	"memory.inc"
%include	"selector.inc"
%include	"call_v86.inc"
%include	"free386.inc"

%if TOWNS
	%include "pc_towns.asm"
%elif PC_98
	%include "pc_98.asm"
%elif PC_AT
	%include "pc_at.asm"
%elif DOS_GENERAL_PURPOSE
	%include "pc_dos.asm"
%endif
