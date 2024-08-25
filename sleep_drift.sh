#!/bin/bash 

UNAME=`uname`

if [[ "${UNAME}" == "Linux" ]] ; then
	HOSTDIR=test_linux
else
	HOSTDIR=test_macos
fi

# timeval::tv_usec at target-wake-up and actual-wake-up times, in microseconds, in times[0] and times[1], respectively
times=(`./elvenrel ${HOSTDIR}/stringx.o ${HOSTDIR}/test_timeval.o --quiet | tail -n 2 | sed -E 's/^[^:]+://'`)
# bc accepts only upper case
times[0]=`echo ${times[0]} | awk '{ print toupper($0) }'`
times[1]=`echo ${times[1]} | awk '{ print toupper($0) }'`
# actual wake-up time (times[1]) may be in the next second past the target wake-up time (times[0])
echo "ibase=16; (${times[1]} < ${times[0]}) * F4240 + ${times[1]} - ${times[0]}" | bc
