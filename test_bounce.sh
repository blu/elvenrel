#!/bin/bash

make all

# Hide term cursor before loading REL; nuke all VMAs originating from common libraries,
# along with the process heap VMA, before passing control to _start; restore term cursor
# upon termination

tput civis
./elvenrel test_bounce.o --filter /lib/aarch64-linux-gnu --filter [heap]
tput cnorm
