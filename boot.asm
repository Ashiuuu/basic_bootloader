[BITS 16]
global _start
extern kernel_start
extern _stage2_sectors

section .text
_start:
	xor ax, ax
	mov ds, ax
	mov es, ax

	; Print some message
	mov si, msg
	call print_string

    ; Loading stage 2 into memory
    ; To read high size images, we need to read in a loop
	xor ax, ax
	mov es, ax              ; ES:BX destination data buffer
	mov bx, 0x8000          ; ES:BX destination data buffer

    mov di, word _stage2_sectors  ; Total number of sectors to read
	; do not override dl, as BIOS but the driver number before jumping on 0x7c00

	; Initial values: Sector 2 | Cylinder 0 | Head 0
	mov cl, 0x02            ; Sector number
	mov ch, 0x00            ; Low eight bits of cylinder number
	mov dh, 0x00            ; Head number

.read_loop:
    cmp di, 0
    jbe .read_success

	; Read sectors from floppy disk
	mov ah, 0x02            ; Read in CHS (Cylinder Head Sector) mode
	mov al, 0x01            ; Because of loop, just read sectors 1 one at a time
	int 0x13                ; Floppy disk/HDD related interrupts
	jc .fail

    dec di                  ; Decrement number of sectors to read
    ; Advance RAM destination
    mov ax, es
    add ax, 0x0020
    mov es, ax

    ; Advance sector
    inc cl
    cmp cl, 19              ; Check if we went around the whole track
    jne .read_loop

    ; We wrapped, increase head and repeat
    mov cl, 1
    inc dh
    cmp dh, 2
    jne .read_loop

    ; We used both heads, change cylinder
    mov dh, 0
    inc ch
    jmp .read_loop

.fail:
	mov si, read_error_msg
	call print_string
	jmp $

.read_success:
	mov si, read_msg
	call print_string

	jmp stage2

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
