#!/bin/bash
BUILD=..

make -C ${BUILD} all > /dev/null

# Load three RELs with cross-relocations

${BUILD}/elvenrel msg_a.o msg_b.o test_order.o --quiet
${BUILD}/elvenrel msg_b.o msg_a.o test_order.o --quiet
