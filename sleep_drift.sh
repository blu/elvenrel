#!/bin/bash

UNAME=`uname`

if [[ "${UNAME}" == "Linux" ]] ; then
	HOSTDIR=test_linux
else
	HOSTDIR=test_macos
fi

# timeval::tv_sec and timeval::tv_usec at target-wake-up and actual-wake-up times, in times[0..3], respectively
times=(`./elvenrel ${HOSTDIR}/stringx.o ${HOSTDIR}/test_timeval.o --quiet | tail -n 2 | awk -F ':' '{ print toupper($1), toupper($2) }'`)
# bc accepts only upper case
echo "ibase=16; (${times[2]} - ${times[0]}) * F4240 + ${times[3]} - ${times[1]}" | bc
