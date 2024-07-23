#!/bin/bash
BUILD=..
COMMON=../test_common

make -C ${BUILD} all

# Hide term cursor before loading RELs; nuke all VMAs from common libraries and
# the process heap VMA, before passing control to _start; suppress reports to
# stdout; restore term cursor upon termination

tput civis
${BUILD}/elvenrel ${COMMON}/memset.o ${COMMON}/test_bounce_data_aosoa_alt_0.o test_bounce_neon_aosoa.o    --filter /lib/aarch64-linux-gnu --filter [heap] --quiet
#${BUILD}/elvenrel ${COMMON}/memset.o ${COMMON}/test_bounce_data_aosoa_alt_1.o test_bounce_neon_aosoa.o    --filter /lib/aarch64-linux-gnu --filter [heap] --quiet
${BUILD}/elvenrel ${COMMON}/memset.o ${COMMON}/test_bounce_data_aosoa_alt_2.o test_bounce_neon_aosoa.o    --filter /lib/aarch64-linux-gnu --filter [heap] --quiet
${BUILD}/elvenrel ${COMMON}/memset.o ${COMMON}/test_bounce_data_aosoa_alt_3.o test_bounce_neon_aosoa.o    --filter /lib/aarch64-linux-gnu --filter [heap] --quiet
${BUILD}/elvenrel ${COMMON}/memset.o ${COMMON}/test_bounce_data_aosoa_alt_2.o test_bounce_neon_aosoa_bg.o --filter /lib/aarch64-linux-gnu --filter [heap] --quiet
tput cnorm
