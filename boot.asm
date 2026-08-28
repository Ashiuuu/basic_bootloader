[BITS 16]
global _start
extern kernel_start
extern _total_sectors

section .text
_start:
	xor ax, ax
	mov ds, ax
	mov es, ax

	; Print some message
	mov si, msg
	call print_string

	; Read sectors from floppy disk
	xor ax, ax
	mov es, ax              ; ES:BX destination data buffer
	mov bx, 0x8000          ; ES:BX destination data buffer
	mov dl, 0x00            ; Drive number
	mov ch, 0x00            ; Low eight bits of cylinder number
	mov cl, 0x02            ; Sector number
	mov dh, 0x00            ; Head number
	mov al, _total_sectors  ; Number of sectors to read
	mov ah, 0x02            ; Read in CHS (Cylinder Head Sector) mode
	int 0x13                ; Floppy disk/HDD related interrupts
	jc .fail
	jmp .read_success
.fail:
	mov si, read_error_msg
	call print_string
	jmp $

.read_success:
	mov si, read_msg
	call print_string

	jmp kernel_start

	jmp $ 			; hang

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

read_error_msg db "Disk Read Error", 0
read_msg db "Finished reading sector 2", 0
msg db "Reading sector 2", 0
