#!/bin/bash

CC=${CC:-gcc}
AS=${AS:-as}
SRC=(
	reloc.c
	reloc_add_aarch64.c
)
TARGET=elvenrel
CFLAGS=(
	-std=c11
	-Ofast
	-DNDEBUG
)
LDFLAGS=(
	-lelf
)

set -x

${CC} ${CFLAGS[@]} ${LDFLAGS[@]} ${SRC[@]} -o ${TARGET}

# Provide an ELF REL sample
${AS} test.s -o test.o --strip-local-absolute
