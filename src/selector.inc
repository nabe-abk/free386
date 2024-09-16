
extern	make_selector
extern	make_selector_4k
extern	set_physical_memory

extern	map_memory		;create selector with memory mapping table
extern	make_alias		;make alias selector
extern	make_aliases		;make alias selector by table

;-------------------------------------------------
; free memory management
;-------------------------------------------------
extern	regist_free_memory	;regist free memory block
extern	allocate_RAM		;allocate phisical memory
extern	free_RAM		;free phisical memory
extern	prepare_map_linear_adr	;allocate page table for linear address mapping
extern	allocate_page_table	;allocate one page table

;-------------------------------------------------
; subroutine
;-------------------------------------------------
extern	get_max_alloc_pages	;get maximum allocatable memory(page)
extern	get_selector_info_adr	;get selector infomation address
extern	get_selector_base_ladr	;get selector infomation and base address
extern	get_selector_end_ladr	;get linear address end of selector
extern	set_selector_limit_iadr	;set selector limit with selector info address
extern	search_free_LDTsel	;get unused LDT selector number
extern	reload_all_selector

extern	regist_managed_LDTsel		;regist to managed LDT selector
extern	search_managed_LDTsel		;search from managed LDT selectors
extern	remove_managed_LDTsel		;remove from managed LDT selectors
extern	rewrite_managed_LDTsels_limit	;rewrite managed LDT selector's limit
extern	get_free_linear_adr		;update to create new selector

extern	get_phisical_address

;-------------------------------------------------
; variable
;-------------------------------------------------
extern freeRAM_bm_ladr
extern freeRAM_bm_size
