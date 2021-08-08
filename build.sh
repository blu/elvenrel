#!/bin/bash

CC=${CC:-gcc}
AS=${AS:-as}
SRC=(
	reloc.c
	reloc_add_aarch64.c
)
CFLAGS=(
	-std=c11
	-Ofast
	-DNDEBUG
	-o elvenrel
)
LFLAGS=(
	-lelf
)

set -x

${CC} ${SRC[@]} ${CFLAGS[@]} ${LFLAGS[@]}

# Provide an ELF REL sample
${AS} test.s -o test.o --strip-local-absolute
