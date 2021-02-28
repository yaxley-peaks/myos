global long_mode_start
extern kernel_main
section .text
bits 64     ;we are in long mode

long_mode_start:
    ;we are now required to load 0 into a bunch of registers
    ;just to reset them so cpu can properly work
    mov ax, 0
    mov ss, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    ;print OK by writing directly to vram[begins at 0xb8000]
    mov dword [0xb8000], 0x2f4b2f4f
    call kernel_main
    hlt
