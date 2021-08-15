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

${CC} ${SRC[@]} ${CFLAGS[@]} ${LDFLAGS[@]} -o ${TARGET}

# Provide an ELF REL sample
${AS} test.s -o test.o --strip-local-absolute

# Data-section REL sample
${AS} test_data.s -o test_data.o --strip-local-absolute

# Cross-REL sample
${AS} test_cross1.s -o test_cross1.o --strip-local-absolute
${AS} test_cross2.s -o test_cross2.o --strip-local-absolute
