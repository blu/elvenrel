#!/bin/bash
BUILD=..
COMMON=../test_common

make -C ${BUILD} all

# Hide term cursor before loading RELs; suppress reports to
# stdout; restore term cursor upon termination

tput civis
${BUILD}/elvenrel ${COMMON}/test_bounce_data_aosoa_alt_0.o test_bounce_neon_aosoa.o --quiet
${BUILD}/elvenrel ${COMMON}/test_bounce_data_aosoa_alt_1.o test_bounce_neon_aosoa.o --quiet
${BUILD}/elvenrel ${COMMON}/test_bounce_data_aosoa_alt_2.o test_bounce_neon_aosoa.o --quiet
${BUILD}/elvenrel ${COMMON}/test_bounce_data_aosoa_alt_3.o test_bounce_neon_aosoa.o --quiet
${BUILD}/elvenrel ${COMMON}/test_bounce_data_aosoa_alt_2.o test_bounce_neon_aosoa_bg.o --quiet
tput cnorm
