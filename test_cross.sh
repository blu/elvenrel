#!/bin/bash

make all

# Load two RELs with cross-relocations; nuke all VMAs from common libraries and
# the process heap VMA, before passing control to _start

./elvenrel test_cross_0.o test_cross_1.o --filter /lib/aarch64-linux-gnu --filter [heap]
