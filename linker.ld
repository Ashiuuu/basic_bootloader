ENTRY(_start)
OUTPUT_FORMAT("binary")

SECTIONS
{
	. = 0x7c00;

	.text.boot : {
		stage1.o(.text)
	}

	. = 0x7c00 + 510;
	.boot_sig : {
		SHORT(0xAA55)
	}

    _stage2_start = .;

	. = 0x7e00;
	.text.stage2 0x8000 : AT(0x7e00) {
		stage2.o(.text .text.*)
		stage2.o(.rodata .rodata.*)
		stage2.o(.data .data.*)
		stage2.o(.bss .bss.*)
	}

	_stage2_end = .;

    . = ALIGN(512);

	_kernel_lma_start = .;

	. = 0x100000;

	_kernel_start = .;

	.kernel 0x100000 : AT(_kernel_lma_start) SUBALIGN(4) {
        kernel.o(.text.kernel_main)
        kernel.o(.text .text.*)
        kernel.o(.rodata .rodata.*)
        kernel.o(.data .data.*)
	}

	. = ALIGN(1);

	_kernel_end = .;

	.bss.kernel : {
		kernel.o(.bss .bss.*)
	}

    /DISCARD/ : {
        *(.eh_frame)
        *(.eh_frame_hdr)
        *(.comment)
        *(.note.*)
    }

	_stage2_sectors = (_stage2_end - _stage2_start + 511) / 512;
	_kernel_lba_start = 1 + _stage2_sectors;
	_kernel_size = (_kernel_end - _kernel_start);
	_kernel_sectors = (_kernel_size + 511) / 512;
}
