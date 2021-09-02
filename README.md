## elvenrel

Elven Relativism -- relocation and execution of aarch64 ELF relocatable objects (REL)

Program loads a multitude of ELF REL files, resolves all relocations (currently only SHT_RELA) and if symbol `_start` in some section `.text` is found, passes control to the former.

## ToDo

* Resolution of all (common) relocation types
* Explicit (CLI) control over the mapping addresses of each REL

## Acknowledgements

Files used, with or without modifications, from external repositories:

	linux.org/ arch/arm64/include/asm/insn.h -> insn.h
	linux.org/ arch/arm64/kernel/module.c    -> reloc_add_aarch64.c
	linux.org/ arch/arm64/lib/strlen.S       -> strlen_linux.s

## Building

	$ make all

## Usage

```sh
$ ./elvenrel test_cross1.o test_cross2.o # order of RELs matters for symbol resolution; undefined symbols in later RELs are sought in earlier RELs

$ ./elvenrel test_rodata.o --filter /lib/aarch64-linux-gnu # before executing the REL dispose of VMAs from file mappings containing /lib/aarch64-linux-gnu in the path

$ ./elvenrel test_data.o --filter [heap] # before executing the REL dispose of the VMA designated as `[heap]`, i.e. the process heap
```

## Screenshots

![hello_sample](image/screenshot000.png "hello sample")
![vma_sample](image/screenshot001.png "vma sample")
