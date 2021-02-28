global start 
extern long_mode_start

section .text
bits 32
start:
    mov esp , stack_top ;stack pointer points to stack_top

    call check_multiboot
    call check_cpuid
    call check_long_mode

    ;paging stuff begins here
    call setup_page_tables
    call enable_paging
    lgdt[gdt64.pointer]     ;load gdt. takes in the pointer to gdt
    ;we jump to 64 bit code now
    jmp gdt64.code_segment:long_mode_start  ;which is in main64.asm


check_multiboot:
    cmp eax , 0x36d76289 ;magic multiboot number
    jne .no_multiboot
    ret
.no_multiboot:
    mov al , "M"
    jmp error

check_cpuid:
    ;try to flip id in the flags register
    pushfd          ;push flags to stack
    pop eax         ;put flags in eax
    mov ecx,eax     ;take a copy in ecx
    xor eax , 1<<21 ;21st bit is the id bit
    push eax        ;new flags in eax
    popfd           ;pop eax to flags
    ;we now check if id bit remained flipped
    pushfd          ;get flag back to stack
    pop eax         ;flags in eax
    push ecx        ;restore original flags from before we flipped bit
    popfd
    cmp eax,ecx     ;if flags are equal
    je .no_cpuid    ;bit was not flipped so no cpuid 
    ret
.no_cpuid:
    mov al , "C" ;cpuid
    jmp error

check_long_mode:
    ;check if cpuid supports extended processor info
    ;to do that we:
    mov eax,0x80000000      ;move 0x8000000 to eax
    cpuid                   ;cpuid stores a number greater than what was in eax
                            ;if extended processor info is supported
    cmp eax,0x80000001      ;if value not bigger
    jb .no_long_mode        ;long mode isnt there. we exit


    mov eax,0x80000001      ;magic number for cpuid instruction
    cpuid                   ;if long mode, bit 29(lm bit) of value in edx will
    test edx, 1<<29         ;be set
    jz .no_long_mode        ;no long mode if not set
    ret
.no_long_mode:
    mov al , "L"
    jmp error


setup_page_tables:              ;paging is enabled as soon as long mode is enabled
    ;we are mapping exactly the same virtual address as the physical address
    mov eax,page_table_l3       ;map l3 table
    or eax,0b11                 ;first 2 bits are present, writable flags so we set them
    mov [page_table_l4],eax     ;first entry in l4 table 

    mov eax,page_table_l2       ;map l2 table
    or eax,0b11                 ;present,writable
    mov [page_table_l3],eax     ;first entry in l3 table 
    ;we dont need a l1 map becaise we can make l2 a "huge page" that can refer directly to memory
    ;and a huge page is 2 mb in size and so we have 512 pointers to fill by iterating over
    ;them to give us 1gb
    ;--------------------------------------------------------------------------------------------
    ;begin idendity mapping using a loop
    mov ecx,0                       ;loop counter
.loop:
    mov eax,0x200000                ;put 2MB in eax
    mul ecx                         ;multiply eax with counter to get correct address offset
    or eax, 0b10000011              ;huge page, present, writable
    mov [page_table_l2+ecx*8],eax   ;l2 table + counter * 8 bytes

    inc ecx                         ;increment counter
    cmp ecx, 512                    ;loop until 512 to map whole page
    jne .loop
    
    ret

enable_paging:
    ;pass page table location to cpu by putting it in cr3 reg
    mov eax,page_table_l4          
    mov cr3,eax
    ;enable physical page extention(64 bit page mode)
    ;set the PAE flag in cr4 to do that
    mov eax,cr4
    or eax,1<<5                    ;5th bit is PAE flag
    mov cr4,eax
    ;enable long mode.
    ;to do this we need to read from certain model specific registers. obtain them by
    mov ecx, 0xC0000080             ;moving this magic number to ecx
    rdmsr                           ;read model specific register. puts value in eax
    or eax,1<<8                     ;PAE flag is 8th bit
    wrmsr                           ;write model specific register(from eax)
    ;enable paging
    ;set the paging flag in cr0 to do that
    mov eax,cr0
    or eax,1<<31                    ;31st bit is paging flag
    mov cr0,eax
    ;and we are in 32 bit compatibilty long mode for now. we still lack the gdt
    ret

error:
    ; print "ERR: X" where X is the error code. doesnt make much sense for now
	mov dword [0xb8000], 0x4f524f45 ;E
	mov dword [0xb8004], 0x4f3a4f52 ;R
	mov dword [0xb8008], 0x4f204f20 ;R
	mov byte  [0xb800a], al
	hlt

section .bss
align 4096          ;page tables are 4kb aligned
page_table_l4:
    resb 4096       ;reserve 4kb for l4 page table
page_table_l3:      ;we only have 1 l3 for now but there can be many
    resb 4096 
page_table_l2:      ;multiple of l2 possible too
    resb 4096

stack_bottom:
    resb 4096 * 4 ;16kb stack
stack_top:

section .rodata
gdt64:
	dq 0                                                ; zero entry. required
.code_segment: equ $ - gdt64                            ;$ = current address
	dq (1 << 43) | (1 << 44) | (1 << 47) | (1 << 53)    ;required flags and stuff set
.pointer:                                               ;pointer to gdt
	dw $ - gdt64 - 1                                    ;has the gdt length
	dq gdt64                                            ;and address