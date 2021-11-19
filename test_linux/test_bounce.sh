#!/bin/bash
BUILD=..
COMMON=../test_common

make -C ${BUILD} all

# Hide term cursor before loading REL; nuke all VMAs from common libraries and
# the process heap VMA, before passing control to _start; restore term cursor
# upon termination

tput civis
${BUILD}/elvenrel ${COMMON}/memset32.o test_bounce.o --filter /lib/aarch64-linux-gnu --filter [heap]
tput cnorm
