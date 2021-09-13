#!/bin/bash
BUILD=..

make -C ${BUILD} all

# Hide term cursor before loading REL; restore term cursor
# upon termination

tput civis
${BUILD}/elvenrel test_bounce.o
tput cnorm
