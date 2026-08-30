#!/bin/bash

qemu-system-x86_64 -boot a -hda bootloader.bin -no-reboot -no-shutdown -d int,cpu_reset -serial stdio
