[BITS 16]
global _start
extern kernel_start

section .text
_start:
	xor ax, ax
	mov ds, ax
	mov es, ax

	; Print some message
	mov si, msg
	call print_string

	mov ax, 0x0000
	mov es, ax
	mov bx, 0x7e00
	mov dl, 0x00
	mov ch, 0x00
	mov cl, 0x02
	mov dh, 0x00
	call read_sector

	jmp kernel_start

	jmp $ 			; hang

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

read_sector:
	mov ah, 0x02
	mov al, 0x01
	int 0x13
	jc .fail
	ret
.fail:
	mov si, read_error_msg
	call print_string
	jmp $

read_error_msg db "Disk Read Error", 0
msg db "Reading sector 2", 0


