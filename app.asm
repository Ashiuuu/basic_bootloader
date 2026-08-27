[BITS 16]
global kernel_start

section .text
kernel_start:
	xor ax, ax
	mov ds, ax
	mov es, ax

	; Print some message
	mov si, msg
	call print_string

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

msg db "Hello from kernel", 0

; The setor needs to end with 0xAA55
; One sector is 512 bytes long
; 0xAA55 is 2 bytes long so we need to fill until the 510th byte
; $ is current address
; $$ is address of current section
; $ - $$ is current size of section
times 510 - ( $ - $$ ) db 0
dw 0xAA55

