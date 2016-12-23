
ASM  = 386asm
LINK = 386link
#LINK = run386 -nocrt d:\hc386\bin\386linkp
#LINK = hc386



seg_test.exp: seg_test.obj
 $(LINK) seg_test sub -stack 1000h
