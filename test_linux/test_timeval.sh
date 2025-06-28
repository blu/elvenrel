#!/bin/bash
BUILD=..

make -C ${BUILD} all > /dev/null

# Advance a timeval structure by some us

${BUILD}/elvenrel stringx.o test_timeval.o --quiet
