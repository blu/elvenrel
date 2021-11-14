#!/bin/bash
BUILD=..

make -C ${BUILD} all

# Hide term cursor before loading REL; nuke all VMAs from common libraries and
# the process heap VMA, before passing control to _start; restore term cursor
# upon termination

tput civis
${BUILD}/elvenrel test_bounce_neon.o --filter /lib/aarch64-linux-gnu --filter [heap]
tput cnorm
