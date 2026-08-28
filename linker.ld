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

	. = ALIGN(4096);
	.text.kernel : {
		kernel.o(.text .text.*)
	}

	.rodata.kernel : {
		kernel.o(.rodata .rodata.*)
	}

	.data.kernel : {
		kernel.o(.data .data.*)
	}

	.bss.kernel : {
		kernel.o(.bss .bss.*)
	}

	_kernel_end = .;

	_total_sectors = (_kernel_end - _stage2_start + 511) / 512;
}
