[BITS 16]
global stage2
extern kernel_main
extern _kernel_lba_start
extern _kernel_sectors

section .text
stage2:
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

print_string:
.print_loop:
	lodsb 			; Load byte from [DS:SI] into AL, increment SI
	cmp al, 0		; Is it null terminator ?
	je .done
	mov ah, 0x0E	; Teletype BIOS
	mov bh, 0x00 	; Display page 0
	mov bl, 0x07 	; White on black color
	int 0x10	 	; Call BIOS function
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
    ; 0x10: 32 bit protected mode kernel data segment
    dw 0xFFFF
    dw 0
    db 0
    db 10010010b
    db 11001111b
    db 0
    ; 0x18: 64 bit long mode kernel code segment
    dw 0xFFFF
    dw 0
    db 0
    db 10011010b
    db 10101111b
    db 0
    ; 0x20: 64 bit long mode kernel data segment
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
	; 32 bit kernel data GDT entry
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov gs, ax

    ; print blue P
    mov byte [0x0B8000], 'P'
    mov byte [0x0B8001], 1Bh

    ; We want to read the large size kernel into high memory 0x00100000
    ; For this, well we need an ATA driver
	; For some reason, putting kernel to load at 0x100000 also in the disk caused some error
	; Never understood why though, so just keep the disk image tight
	; Or for some reason it seemed like it was reading too much sectors
	; Even though values provided by linker.ld were correct
    pushad

    mov eax, _kernel_lba_start  ; Start sector for the kernel
    mov ecx, _kernel_sectors    ; Number of sectors to load
    mov edi, 0x00100000         ; Destination address in RAM

    mov esi, eax                ; ESI Contains the current LBA sector

.read_chunk_loop:
    cmp ecx, 0                  ; Number of sectors left to read
    jbe .done

    ; 1. Calculate the number of sectors to read in this batch
    ; 28 bit LBA allows for 255 sectors maximum at a time
    mov ebx, 255
    cmp ecx, ebx
    jbe .use_remaining          ; Less than 255 sectors to read, just read everything
    jmp .issue_command

.use_remaining:
    mov ebx, ecx

.issue_command:
    ; From now: EBX contains either 255 or ECX if ECX < 255

    mov dx, 0x1F2               ; Sector count register (Base + 0x2)
    mov al, bl
    out dx, al                  ; Send number of sectors to read to register

    mov dx, 0x1F3               ; LBA low register
    mov eax, esi                ; Retrieve current LBA
    out dx, al                  ; Sent current starting LBA

    mov dx, 0x1F4               ; LBA mid register
    shr eax, 8                  ; Erase low bits and get AL to contain mid bits
    out dx, al

    mov dx, 0x1F5               ; LBA high register
    shr eax, 8                  ; Same as mid bits
    out dx, al

    mov dx, 0x1F6               ; Rest of LBA + Flags
    shr eax, 8                  ; Get remaining bits
    and al, 0x0F                ; In Driver register, bits 0-3 are bits 24-27 of current LBA
    or al, 0xE0                 ; bits 5 & 7 should always be set, 4 is driver number and 6 set tells that we use LBA
    out dx, al

    mov dx, 0x1F7               ; Command register (issue read command)
    mov al, 0x20
    out dx, al


    ; Read batch
    push ecx
    mov ecx, ebx

.sector_loop:
    push ecx

    ; stall 400 nano seconds
    mov dx, 0x3F6
    in al, dx
    in al, dx
    in al, dx
    in al, dx

    mov dx, 0x1F7
    ; Poll until ready to read
.wait_ready:
    in al, dx

    test al, 0x80               ; Test for BSY bit first, because when it is set all the rest is meaningless
    jnz .wait_ready

    test al, 0x01               ; Test for error
    jnz .ata_error

    test al, 0x08               ; Test for DRQ bit
    jz .wait_ready

    mov ecx, 256				; Reading code again, it works but maybe it should be 255?
    mov dx, 0x1F0
    rep insw                    ; rep decrements ecx and insd increments edi

    ; Stall again
    mov dx, 0x3F6
    in al, dx
    in al, dx
    in al, dx
    in al, dx

    ; Query status port to avoid IRQ
    mov dx, 0x1F7
    in al, dx

    pop ecx
    loop .sector_loop           ; loop decrements ecx

    ; Advance to next batch
    pop ecx                     ; Restore number of sectors remaining
    sub ecx, ebx                ; Substract the number of sectors we just batched
    add esi, ebx                ; Advance current LBA by batch count
    jmp .read_chunk_loop

.ata_error:
    xor eax, eax
    mov dx, 0x1F1
    in al, dx
    mov eax, 0xDEADEAD
    hlt

.done:
    popad

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

    ; Enable Long Mode bit in MSR register
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr

    ; Enable paging
    mov eax, cr0
    or eax, (1 << 31)
    mov cr0, eax

    ; 3. Jump to 64 bit code (the actual kernel!)
    jmp 0x18:realm64

[BITS 64]
realm64:
    mov ax, 0x20
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov gs, ax
    mov fs, ax
    mov rsp, 0x90000				; Reading code again, maybe not suitable for stack?

	; Print 'L' on screen
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
