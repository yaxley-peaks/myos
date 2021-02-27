global start 

section .text
bits 32
start:
    ;print OK by writing directly to vram[begins at 0xb8000]
    mov dword [0xb8000], 0x2f4b2f4f
    hlt