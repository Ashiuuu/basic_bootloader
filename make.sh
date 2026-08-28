#!/bin/bash

nasm -f elf64 boot.asm -o stage1.o
nasm -f elf64 app.asm -o stage2.o
ld -m elf_x86_64 -T linker.ld stage1.o stage2.o kernel.o -o bootloader.bin
