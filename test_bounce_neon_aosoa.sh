#!/bin/bash

make all

# Hide term cursor before loading RELs; restore term cursor upon termination

tput civis
./elvenrel test_bounce_data_aosoa_alt_0.o test_bounce_neon_aosoa.o
./elvenrel test_bounce_data_aosoa_alt_1.o test_bounce_neon_aosoa.o
./elvenrel test_bounce_data_aosoa_alt_0.o test_bounce_neon_aosoa.o
./elvenrel test_bounce_data_aosoa_alt_1.o test_bounce_neon_aosoa.o
tput cnorm
