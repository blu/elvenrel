#!/bin/bash
BUILD=..
COMMON=../test_common

make -C ${BUILD} all

# De-nice ourselves and our kitty term emu for smooth fps; some root required

DENICE=
PID_KITTY=

if [[ $# == 1 ]] && [[ $1 == "denice" ]] ; then

	DENICE="sudo nice -n -20"

	# Check if terminal is kitty -- normally our terminal should be our grandpatent

	PID_KITTY=`ps -p $PPID -o ppid=''`
	COMM_KITTY=`ps -p $PID_KITTY -o command='' -c`

	if [[ ${COMM_KITTY} != "kitty" ]] ; then
		PID_KITTY=
	fi
fi

# Boost kitty to top warp

if [[ ! -z ${PID_KITTY} ]] ; then
	sudo renice -n -20 -p ${PID_KITTY}
fi

# Hide term cursor before loading RELs; suppress reports to
# stdout; restore term cursor upon termination

tput civis
${DENICE} ${BUILD}/elvenrel ${COMMON}/memset.o ${COMMON}/test_bounce_data_aosoa_alt_0.o test_bounce_neon_aosoa.o    --quiet
${DENICE} ${BUILD}/elvenrel ${COMMON}/memset.o ${COMMON}/test_bounce_data_aosoa_alt_1.o test_bounce_neon_aosoa.o    --quiet
${DENICE} ${BUILD}/elvenrel ${COMMON}/memset.o ${COMMON}/test_bounce_data_aosoa_alt_2.o test_bounce_neon_aosoa.o    --quiet
${DENICE} ${BUILD}/elvenrel ${COMMON}/memset.o ${COMMON}/test_bounce_data_aosoa_alt_3.o test_bounce_neon_aosoa.o    --quiet
${DENICE} ${BUILD}/elvenrel ${COMMON}/memset.o ${COMMON}/test_bounce_data_aosoa_alt_2.o test_bounce_neon_aosoa_bg.o --quiet
tput cnorm

# De-boost kitty to normal warp

if [[ ! -z ${PID_KITTY} ]] ; then
	sudo renice -n 20 -p ${PID_KITTY}
fi
