#!/bin/bash
BUILD=..
COMMON=../test_common

make -C ${BUILD} all > /dev/null

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

# Hide term cursor before loading REL; restore term cursor
# upon termination

tput civis
${DENICE} ${BUILD}/elvenrel ${COMMON}/memset.o test_bounce_neon.o
tput cnorm

# De-boost kitty to normal warp

if [[ ! -z ${PID_KITTY} ]] ; then
	sudo renice -n 20 -p ${PID_KITTY}
fi
