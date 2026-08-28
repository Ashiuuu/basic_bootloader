[BITS 16]
global kernel_start
extern kernel_main

section .text
kernel_start:
	; Print some message
	mov si, msg
	call print_string

    ; Enable A20 line to access all of memory
    in al, 0x92
    or al, 2
    out 0x92, al

    ; Switch to protected mode:
    ; 1. disable interrupts
    cli

    ; 2. Load GDT
    xor ax, ax
    mov ds, ax
    lea si, [gdt_desc]
    lgdt [si]

    ; 3. Set PE (Protection Enable) bit in CR0
    mov eax, cr0
    or al, 1
    mov cr0, eax

    jmp 0x08:clear_pipe

print_char:
	mov ah, 0x0E	; Teletype BIOS
	mov bh, 0x00 	; Display page 0
	mov bl, 0x07 	; White on black color
	int 0x10	 	; Call BIOS function
	ret

print_string:
.print_loop:
	lodsb 			; Load byte from [DS:SI] into AL, increment SI
	cmp al, 0		; Is it null terminator ?
	je .done
	call print_char
	jmp .print_loop
.done:
	ret

msg db "Hello from app", 0

; GDT definition
; In flat model, each entry has:
; Base=0
; Limit = 0xFFFFF
; Flags = 0xC
; Access Byte depends on segment
; Only use 1 GDT for both 32 (protected) and 64 (long) bits modes
align 8
gdt_start:
    dq 0 ; null entry
    ; 0x08: 32 bit protected mode kernel code segment (used for transition to long mode)
    dw 0xFFFF               ; Start of Limit
    dw 0                    ; Base bits 0-15
    db 0                    ; Base bits 16-23
    db 10011010b            ; Access Byte (Mandatory P, Kernel DPL, Code segment (S & E), DC confirming bit, read allowed, accessed bit)
    db 11001111b            ; flags (4KB granularity G & 32-bit segment DB) | Limit
    db 0                    ; End of Base
    ; 0x10: 64 bit long mode kernel code segment
    dw 0xFFFF
    dw 0
    db 0
    db 10011010b
    db 10101111b
    db 0
    ; 0x18: 64 bit long mode kernel data segment
    dw 0xFFFF
    dw 0
    db 0
    db 10010010b
    db 10101111b
    db 0
gdt_end:

; Descriptor passed to lgdt instruction that states the length of the GDT
align 8
gdt_desc:
    dw gdt_end - gdt_start - 1
    dd gdt_start

[BITS 32]
clear_pipe:
    ; print blue P
    mov byte [0x0B8000], 'P'
    mov byte [0x0B8001], 1Bh

    ; Now we want to go into long mode (64 bits)
    ; 1. Disable paging (should not be enabled, but we never know)
    mov eax, cr0
    and eax, ~ ( 1 << 31 )
    mov cr0, eax

    ; 2. Setting up PAE
    ; Link PML4 entry 0 to PDPT
    mov eax, pdpt
    or eax, 0x03 ; Present | R/W
    mov [pml4], eax
    ; Link PDPT entry 0 to PD
    mov eax, pd
    or eax, 0x03
    mov [pdpt], eax
    ; Link PD entry 0 to physical memory
    mov dword [pd], 0x00000083      ; Present | Writable | Page Size
    mov dword [pd + 4], 0x00000000  ; Upper 32 bits of address

    ; Then load PML4 into cr3
    mov eax, pml4
    mov cr3, eax

    ; Enable PAE
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax

    ; Enable paging
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr

    ; Enable paging
    mov eax, cr0
    or eax, (1 << 31)
    mov cr0, eax

    ; 3. Jump to 64 bit code (the actual kernel!)
    jmp 0x10:final_main

[BITS 64]
final_main:
    mov ax, 0x18
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov gs, ax
    mov fs, ax
    mov rsp, 0x90000

    mov byte [0x0B8000], 'L'
    mov byte [0x0B8001], 1Bh

    call kernel_main

.hang:
    cli
    hlt
    jmp .hang

section .bss
align 4096
pml4: resb 4096
pdpt: resb 4096
pd: resb 4096
