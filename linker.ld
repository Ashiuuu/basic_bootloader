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

	. = 0x7e00;
	.text.stage2 : {
		stage2.o(.text)
		*(.rodata*)
		*(.data)
		*(.bss)
	}
}
