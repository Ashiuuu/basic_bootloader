#!/bin/bash

qemu-system-x86_64 -boot a -fda bootloader.bin -no-reboot -no-shutdown -d int,cpu_reset
