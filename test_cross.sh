#!/bin/bash

make all

# Load two RELs with cross-relocations; nuke all VMAs originating from common libraries,
# along with the process heap VMA, before passing control to _start
./elvenrel test_cross1.o test_cross2.o --filter /lib/aarch64-linux-gnu --filter [heap]
