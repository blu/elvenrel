#!/bin/bash

make all

# Hide term cursor before loading RELs; nuke all VMAs from common libraries and
# the process heap VMA, before passing control to _start; suppress reports to
# stdout; restore term cursor upon termination

tput civis
./elvenrel test_bounce_data_aosoa_alt_0.o test_bounce_neon_aosoa.o --filter /lib/aarch64-linux-gnu --filter [heap] --quiet
./elvenrel test_bounce_data_aosoa_alt_1.o test_bounce_neon_aosoa.o --filter /lib/aarch64-linux-gnu --filter [heap] --quiet
./elvenrel test_bounce_data_aosoa_alt_2.o test_bounce_neon_aosoa.o --filter /lib/aarch64-linux-gnu --filter [heap] --quiet
./elvenrel test_bounce_data_aosoa_alt_3.o test_bounce_neon_aosoa.o --filter /lib/aarch64-linux-gnu --filter [heap] --quiet
tput cnorm
