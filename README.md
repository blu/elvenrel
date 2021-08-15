## elvenrel

Elven Relativism -- relocation and execution of ELF relocatable objects (REL)

Program loads a multitude of ELF REL files, resolves all relocations (currently only SHT_RELA) and if symbol `_start` in some section `.text` is found, passes control to the former.

## ToDo

* Resolution of all (common) relocation types
* Explicit (CLI) control over the mapping addresses of each REL
* Explicit (CLI) control over the process VMAs before passing control to `_start`

## Acknowledgements

Files used, with or without modifications, from external repositories:

	linux.org/ arch/arm64/include/asm/insn.h -> insn.h
	linux.org/ arch/arm64/kernel/module.c    -> reloc_add_aarch64.c

## Building

	$ make all

## Usage

	$ ./elvenrel test_cross1.o test_cross2.o # order of RELs matters for symbol resolution; undefined symbols in later RELs are sought in earlier RELs

## Screenshots

![hello_sample](image/screenshot000.png "hello sample")
